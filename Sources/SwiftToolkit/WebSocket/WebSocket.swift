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
                let delegate = WebSocketTaskDelegate { _ in
                    await self.handleConnect()
                    continuation.resume()

                } onWebSocketTaskDidClose: { closeCode, reason in
                    await self.handleDisconnect(withError: nil, closeCode: closeCode, reason: reason)

                } onWebSocketTaskDidCompleteWithError: { error in
                    guard let error else {
                        return
                    }
                    if case .connecting = await self.state {
                        continuation.resume(throwing: error)
                    } else {
                        await self.handleDisconnect(withError: error, closeCode: nil, reason: nil)
                    }
                }

                self.socketTaskDelegate = delegate
                socketTask.delegate = delegate

                socketTask.resume()
            }
        } catch {
            state = .notConnected
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
        guard state == .connected else {
            throw WebSocketError.notConnected
        }

        socketTask.cancel(with: closeCode, reason: reason?.data(using: .utf8))

        // Wait for the OS to tell us the socketTask is actually disconnected
        await _ = stateEvents.first { state in
            switch state {
            case .disconnected: true
            default: false
            }
        }

        messagesContinuation.finish()
        socketTaskDelegate = nil
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
                try await send(data)
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

            default:
                break
            }
        }
    }

    private func handleConnect() {
        state = .connected
        stateEventsContinuation.yield(.connected)

        receive()

        switch heartbeats {
        case .disabled:
            break
        case let .enabled(kind, interval):
            startHeartbeats(kind: kind, every: interval)
        }
    }

    private func handleDisconnect(
        withError error: Error?,
        closeCode: URLSessionWebSocketTask.CloseCode?,
        reason: Data?
    ) {
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
