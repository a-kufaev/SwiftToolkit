//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2025 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

// swiftlint:disable all

import Foundation

public actor WebSocket {
    public private(set) var state: State = .notConnected

    /// A stream of messages received by the socket.
    ///
    /// This stream will finish when the socket disconnects as expected,
    /// or throws when the socket disconnects due to an error.
    public nonisolated let messages: AsyncThrowingStream<Message, Error>

    /// A stream of changes to the socket state.
    ///
    /// This stream will finish after the socket disconnects.
    public nonisolated let stateEvents: AsyncStream<StateChangedEvent>

    private let socketTask: URLSessionWebSocketTask
    private var socketTaskDelegate: WebSocketTaskDelegate?

    private let messagesContinuation: AsyncThrowingStream<Message, Error>.Continuation
    private let stateEventsContinuation: AsyncStream<StateChangedEvent>.Continuation
    private let heartbeats: Heartbeats
    private var heartbeatTask: Task<Void, Error>?
    private var pingAttempt: Int = .zero
    private let pingQueue = AsyncQueue()
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var disconnectContinuation: CheckedContinuation<Void, Never>?

    /// `disconnect()` waits this long for URLSession to confirm the cancelled task before closing on its own.
    private static let disconnectTimeout: Duration = .seconds(5)

    /// Initializes a new WebSocket.
    ///
    /// - Parameters:
    ///   - request: The URLRequest used for connecting the WebSocket.
    ///   - urlSession: The URLSession used for connect the WebSocket.
    ///   - heartbeats: Whether to send heartbeats after connecting.
    public init(
        request: URLRequest,
        urlSession: URLSession = URLSession.shared,
        heartbeats: Heartbeats = .disabled
    ) {
        let (messagesStream, messagesContinuation) = AsyncThrowingStream.makeStream(
            of: Message.self,
            throwing: Error.self
        )
        messages = messagesStream
        self.messagesContinuation = messagesContinuation

        let (stateEvents, stateEventsContinuation) = AsyncStream.makeStream(of: StateChangedEvent.self)
        self.stateEvents = stateEvents
        self.stateEventsContinuation = stateEventsContinuation

        socketTask = urlSession.webSocketTask(with: request)
        self.heartbeats = heartbeats
    }

    public init(
        url: URL,
        urlSession: URLSession = URLSession.shared,
        heartbeats: Heartbeats = .disabled
    ) {
        self.init(request: URLRequest(url: url), urlSession: urlSession, heartbeats: heartbeats)
    }

    deinit {
        messagesContinuation.finish()
        stateEventsContinuation.finish()
        socketTask.cancel()
        socketTaskDelegate = nil
    }

    // MARK: - Connecting / Disconnecting

    /// Connects the WebSocket. You may only call this once per instance.
    ///
    /// After the WebSocket disconnects, it can no longer be connected. If you want to establish a new connection
    /// you must create a new WebSocket instance.
    ///
    /// - Throws WebSocketError.alreadyConnectedOrConnecting when the socket is already connected or connecting.
    public func connect() async throws {
        guard state == .notConnected else {
            throw WebSocketError.alreadyConnectedOrConnecting
        }

        state = .connecting
        stateEventsContinuation.yield(.connecting)

        do {
            try await withCheckedThrowingContinuation { continuation in
                connectContinuation = continuation

                let delegate = WebSocketTaskDelegate { _ in
                    await self.handleConnect()

                } onWebSocketTaskDidClose: { closeCode, reason in
                    await self.handleDisconnect(withError: nil, closeCode: closeCode, reason: reason)

                } onWebSocketTaskDidCompleteWithError: { error in
                    await self.handleTaskCompletion(error: error)
                }

                self.socketTaskDelegate = delegate
                socketTask.delegate = delegate

                socketTask.resume()
            }
        } catch {
            // One-shot: a failed handshake ends this instance the way a disconnect does, so both streams finish
            // and a second `connect()` on the same instance is refused instead of running against dead streams.
            state = .disconnected
            stateEventsContinuation.finish()
            messagesContinuation.finish()
            throw error
        }
    }

    /// Disconnects the WebSocket.
    ///
    /// After the WebSocket disconnects, it can no longer be connected. If you want to establish a new connection
    /// you must create a new WebSocket instance.
    ///
    /// - Parameters:
    ///   - closeCode: A close code that indicates the reason for closing the connection.
    ///   - reason: Optional further information to explain the closing.
    ///
    /// - Throws WebSocketError.notConnected when the WebSocket is not connected.
    public func disconnect(
        closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure,
        reason: String? = nil
    ) async throws {
        guard state == .connected, disconnectContinuation == nil else {
            throw WebSocketError.notConnected
        }

        socketTask.cancel(with: closeCode, reason: reason?.data(using: .utf8))

        // Wait for the OS to confirm the task ended; `handleDisconnect` resumes this, so `stateEvents` keeps its
        // single consumer. A callback that never comes must not hang the caller.
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.disconnectTimeout)
            guard !Task.isCancelled else { return }
            await self?.handleDisconnect(withError: URLError(.timedOut), closeCode: nil, reason: nil)
        }
        await withCheckedContinuation { continuation in
            disconnectContinuation = continuation
        }
        timeout.cancel()
    }

    // MARK: - Sending Data

    /// Sends the given encodable `value` through the WebSocket.
    ///
    /// - Parameters:
    ///   - value: The encodable value that is sent through the websocket.
    ///   - encoder: The encoder used to encode the value.
    ///
    /// - Throws WebSocketError.notConnected when the `send` method is called before the WebSocket is connected.
    public func send(_ value: any Encodable) async throws {
        let data = try JSONEncoder().encode(value)
        let string = String(data: data, encoding: .utf8) ?? ""
        try await send(.string(string))
    }

    /// Sends the given `string` through the websocket.
    ///
    /// - Throws WebSocketError.notConnected when the `send` method is called before the WebSocket is connected.
    public func send(_ string: String) async throws {
        try await send(.string(string))
    }

    // MARK: - Heartbeats

    /// Start sending a heartbeat at regular intervals.
    ///
    /// - Parameters:
    ///   - heartbeat: The heartbeat data to send.
    ///   - interval: The interval between heartbeats.
    private func startHeartbeats(kind: Heartbeats.Kind, every interval: Duration) {
        heartbeatTask?.cancel()

        heartbeatTask = Task {
            pingAttempt = 0
            guard !Task.isCancelled else { return }
            switch kind {
            case .native:
                socketTask.sendPing { [weak self, weak pingQueue] error in
                    guard !Task.isCancelled, let self, let pingQueue else { return }
                    pingQueue.enqueue(on: self) { actor in
                        guard error != nil else {
                            actor.pingAttempt = 0
                            return
                        }
                        actor.pingAttempt = 0
                        if await self.pingAttempt > 3 {
                            try? await actor.disconnect(closeCode: .invalid)
                        }
                    }
                }
            case let .customMessage(data):
                do {
                    try await send(data)
                } catch {
                    // A heartbeat that cannot be sent is a dead task the delegate has not reported; close it here
                    // instead of letting the heartbeat task die unobserved while `state` stays `.connected`.
                    socketTask.cancel()
                    handleDisconnect(withError: error, closeCode: nil, reason: nil)
                    return
                }
            }

            try await Task.sleep(for: interval)
            startHeartbeats(kind: kind, every: interval)
        }
    }

    /// Stop sending heartbeats.
    private func stopHeartbeats() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Private

    private func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard state == .connected else {
            throw WebSocketError.notConnected
        }

        try await socketTask.send(message)
    }

    private nonisolated func receive() {
        socketTask.receive { [weak self] result in
            switch result {
            case let .success(.data(data)):
                self?.messagesContinuation.yield(.data(data))
                self?.receive()

            case let .success(.string(string)):
                self?.messagesContinuation.yield(.string(string))
                self?.receive()

            case let .failure(error):
                self?.messagesContinuation.yield(.invalid(error))

            @unknown default:
                self?.receive()
            }
        }
    }

    private func handleConnect() {
        // A task that already failed or closed must not be revived by a late didOpen.
        guard state == .connecting else { return }

        state = .connected
        stateEventsContinuation.yield(.connected)
        connectContinuation?.resume()
        connectContinuation = nil

        receive()

        switch heartbeats {
        case .disabled:
            break
        case let .enabled(kind, interval):
            startHeartbeats(kind: kind, every: interval)
        }
    }

    private func handleTaskCompletion(error: Error?) {
        if state == .connecting {
            // The task ended before it opened: a failed handshake.
            connectContinuation?.resume(throwing: error ?? URLError(.cancelled))
            connectContinuation = nil
            return
        }
        // With `error == nil` this normally follows didCloseWith and is a no-op below; without a prior close
        // frame the task is dead all the same, so it must not leave `state` at `.connected`.
        handleDisconnect(withError: error, closeCode: nil, reason: nil)
    }

    private func handleDisconnect(
        withError error: Error?,
        closeCode: URLSessionWebSocketTask.CloseCode?,
        reason: Data?
    ) {
        // didCloseWith, didCompleteWithError, a failed heartbeat and the disconnect timeout can all report the
        // same death; the first one wins.
        guard state == .connected else { return }

        state = .disconnected
        stateEventsContinuation.yield(
            .disconnected(
                closeCode: closeCode,
                reason: reason.flatMap { String(data: $0, encoding: .utf8) },
                error: error
            )
        )
        stateEventsContinuation.finish()

        messagesContinuation.finish(throwing: error)
        socketTaskDelegate = nil
        stopHeartbeats()

        disconnectContinuation?.resume()
        disconnectContinuation = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

private final class WebSocketTaskDelegate: NSObject, URLSessionWebSocketDelegate {

    private let onWebSocketTaskDidOpen: @Sendable (_ protocol: String?) async -> Void
    private let onWebSocketTaskDidClose:
        @Sendable (_ code: URLSessionWebSocketTask.CloseCode, _ reason: Data?) async -> Void
    private let onWebSocketTaskDidCompleteWithError: @Sendable (_ error: Error?) async -> Void

    init(
        onWebSocketTaskDidOpen: @Sendable @escaping (_: String?) async -> Void,
        onWebSocketTaskDidClose: @Sendable @escaping (
            _: URLSessionWebSocketTask.CloseCode, _: Data?
        ) async -> Void,
        onWebSocketTaskDidCompleteWithError: @Sendable @escaping (_: Error?) async -> Void
    ) {
        self.onWebSocketTaskDidOpen = onWebSocketTaskDidOpen
        self.onWebSocketTaskDidClose = onWebSocketTaskDidClose
        self.onWebSocketTaskDidCompleteWithError = onWebSocketTaskDidCompleteWithError
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didOpenWithProtocol proto: String?
    ) {
        Task {
            await onWebSocketTaskDidOpen(proto)
        }
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task {
            await onWebSocketTaskDidClose(closeCode, reason)
        }
    }

    func urlSession(
        _: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?
    ) {
        Task {
            await onWebSocketTaskDidCompleteWithError(error)
        }
    }
}

// swiftlint:enable all
