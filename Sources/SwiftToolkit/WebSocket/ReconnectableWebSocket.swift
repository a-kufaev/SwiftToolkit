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

import Foundation

public actor ReconnectableWebSocket {

    /// A stream of messages received by the socket.
    ///
    /// This stream will only finish when ReconnectableWebSocket deinitializes.
    public nonisolated let messages: AsyncStream<WebSocket.Message>

    /// A stream of changes to the socket state.
    ///
    /// This stream will only finish when ReconnectableWebSocket deinitializes.
    public nonisolated let stateEvents: AsyncStream<WebSocket.StateChangedEvent>

    /// The current connection's state; `.notConnected` once the last connection has been retired.
    public var state: WebSocket.State {
        get async {
            await webSocket?.state ?? .notConnected
        }
    }

    private let connector: () async -> URLRequest
    private let makeConnection: @Sendable (URLRequest) -> any WebSocketConnection

    private let messagesContinuation: AsyncStream<WebSocket.Message>.Continuation
    private let stateEventsContinuation: AsyncStream<WebSocket.StateChangedEvent>.Continuation

    private var webSocket: (any WebSocketConnection)?
    private var isConnecting = false

    /// Create a WebSocket whose streams survive reconnects. Reconnecting itself is the caller's job: after a
    /// disconnect, `connect()` may be called again and opens a fresh connection.
    ///
    /// Every time the WebSocket (re)connects, the `connector` closure is called to obtain a new `URLRequest`.
    ///
    /// - Parameters:
    ///   - urlSession: The URLSession used when connecting the WebSocket.
    ///   - heartbeats: Whether to send heartbeats after connecting.
    ///   - connector: A closure that returns a URLRequest used to connect the WebSocket. This closure will be called
    ///                every time the web WebSocket connects.
    public init(
        urlSession: URLSession = URLSession.shared,
        heartbeats: WebSocket.Heartbeats = .disabled,
        connector: @escaping () async -> URLRequest
    ) {
        self.init(connector: connector) { request in
            WebSocket(request: request, urlSession: urlSession, heartbeats: heartbeats)
        }
    }

    public init(
        urlSession: URLSession = URLSession.shared,
        heartbeats: WebSocket.Heartbeats = .disabled,
        connector: @escaping () async -> URL
    ) {
        self.init(urlSession: urlSession, heartbeats: heartbeats) {
            await URLRequest(url: connector())
        }
    }

    init(
        connector: @escaping () async -> URLRequest,
        makeConnection: @escaping @Sendable (URLRequest) -> any WebSocketConnection
    ) {
        let (messagesStream, messagesContinuation) = AsyncStream.makeStream(of: WebSocket.Message.self)
        messages = messagesStream
        self.messagesContinuation = messagesContinuation

        let (stateEvents, stateEventsContinuation) = AsyncStream.makeStream(of: WebSocket.StateChangedEvent.self)
        self.stateEvents = stateEvents
        self.stateEventsContinuation = stateEventsContinuation

        self.connector = connector
        self.makeConnection = makeConnection
    }

    deinit {
        messagesContinuation.finish()
        stateEventsContinuation.finish()
    }

    /// Connects the WebSocket.
    ///
    /// - Throws WebSocketError.alreadyConnectedOrConnecting when the socket is already connected or connecting.
    public func connect() async throws {
        let validStates = [WebSocket.State.notConnected, .disconnected]

        guard !isConnecting, await validStates.contains(state) else {
            throw WebSocketError.alreadyConnectedOrConnecting
        }
        isConnecting = true
        defer { isConnecting = false }

        let webSocket = await makeConnection(connector())
        self.webSocket = webSocket

        forwardStreams(of: webSocket)

        try await webSocket.connect()
    }

    /// Disconnects the WebSocket.
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
        guard let webSocket else {
            throw WebSocketError.notConnected
        }

        try await webSocket.disconnect(closeCode: closeCode, reason: reason)
    }

    // MARK: - Sending Data

    /// Sends the given encodable `value` through the WebSocket.
    ///
    /// - Parameters:
    ///   - value: The encodable value that is sent through the websocket.
    ///
    /// - Throws WebSocketError.notConnected when the `send` method is called before the WebSocket is connected.
    public func send(_ value: any Encodable & Sendable) async throws {
        try await liveConnection().send(value)
    }

    /// Sends the given `string` through the websocket.
    ///
    /// - Throws WebSocketError.notConnected when the `send` method is called before the WebSocket is connected.
    public func send(_ string: String) async throws {
        try await liveConnection().send(string)
    }

    /// Sends the given `data` through the WebSocket.
    ///
    /// - Throws WebSocketError.notConnected when the `send` method is called before the WebSocket is connected.
    public func send(_ data: Data) async throws {
        try await liveConnection().send(data)
    }

    // MARK: - Private

    /// One guard for every send. The connection comes back non-optional, so a retire between the check and the
    /// send can no longer turn `try await webSocket?.send(...)` into a silent success.
    private func liveConnection() async throws -> any WebSocketConnection {
        guard let webSocket, await webSocket.state == .connected else {
            throw WebSocketError.notConnected
        }
        return webSocket
    }

    /// Both forwarders live exactly as long as the connection's streams and are never cancelled. The state
    /// forwarder is the only place a connection is retired, and only after `.disconnected` has been forwarded.
    private func forwardStreams(of webSocket: any WebSocketConnection) {
        Task { [weak self] in
            do {
                for try await message in webSocket.messages {
                    guard let self else { return }
                    messagesContinuation.yield(message)
                }
            } catch {
                // A throwing finish is always paired with `.disconnected` on `stateEvents`.
            }
        }

        Task { [weak self] in
            for await event in webSocket.stateEvents {
                guard let self else { return }
                stateEventsContinuation.yield(event)
                if case .disconnected = event {
                    await retire(webSocket)
                }
            }
        }
    }

    private func retire(_ webSocket: any WebSocketConnection) {
        guard self.webSocket === webSocket else { return }
        self.webSocket = nil
    }
}
