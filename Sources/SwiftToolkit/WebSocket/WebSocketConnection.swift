//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2026 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation

/// The one-connection surface `ReconnectableWebSocket` drives. `WebSocket` is the production conformer;
/// tests substitute a fake that controls `state` and finishes both streams in a chosen order.
///
/// Contract: both streams finish on every exit of the connection (disconnect, failed connect, deinit).
/// `ReconnectableWebSocket` never cancels its forwarders — it relies on this.
protocol WebSocketConnection: Actor {
    nonisolated var messages: AsyncThrowingStream<WebSocket.Message, Error> { get }
    nonisolated var stateEvents: AsyncStream<WebSocket.StateChangedEvent> { get }
    var state: WebSocket.State { get }

    func connect() async throws
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: String?) async throws
    func send(_ value: any Encodable) async throws
    func send(_ string: String) async throws
}

extension WebSocket: WebSocketConnection {}
