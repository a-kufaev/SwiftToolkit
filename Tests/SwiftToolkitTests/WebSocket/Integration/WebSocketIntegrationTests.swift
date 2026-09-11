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
@testable import SwiftToolkit
import Testing

/// Real `WebSocket` over `URLSession` against a loopback server: covers the URLSession delegate paths the fake
/// cannot reach (failed handshake, abrupt drop, close frame, on-demand disconnect).
@Suite("WebSocket integration", .serialized)
struct WebSocketIntegrationTests {

    private static let timeout: Duration = .seconds(5)

    private struct Client {
        let sut: ReconnectableWebSocket
        let states: EventLog<WebSocket.StateChangedEvent>
        let observer: Task<Void, Never>

        init(port: UInt16) {
            let states = EventLog<WebSocket.StateChangedEvent>()
            let sut = ReconnectableWebSocket {
                URLRequest(url: URL(string: "ws://127.0.0.1:\(port)")!)
            }
            self.sut = sut
            self.states = states
            observer = Task {
                for await event in sut.stateEvents {
                    await states.append(event)
                }
            }
        }
    }

    @Test("a failed handshake throws, finishes the streams and allows a fresh connect")
    func failedHandshakeThrowsAndFinishesStreams() async throws {
        let server = try await LocalWebSocketServer.start(upgrade: false)
        defer { server.stop() }
        let client = Client(port: server.port)

        await #expect(throws: (any Error).self) {
            try await client.sut.connect()
        }
        #expect(await client.sut.state == .disconnected)
        let events = await client.states.waitForCount(1, timeout: Self.timeout)
        #expect(events == [.connecting])
        try await Task.sleep(for: .milliseconds(100))
        #expect(disconnectedCount(await client.states.items) == 0)

        await #expect(throws: (any Error).self) {
            try await client.sut.connect()
        }
        #expect(await client.states.waitForCount(2, timeout: Self.timeout) == [.connecting, .connecting])
    }

    @Test("an abrupt drop is forwarded exactly once and the socket reconnects on a fresh connection")
    func abruptDropIsForwardedOnceAndReconnects() async throws {
        let server = try await LocalWebSocketServer.start()
        defer { server.stop() }
        let client = Client(port: server.port)

        try await client.sut.connect()
        #expect(await client.sut.state == .connected)
        #expect(await eventually(timeout: Self.timeout) { server.connectionCount == 1 })

        server.dropAll()

        let events = await client.states.waitForCount(3, timeout: Self.timeout)
        #expect(disconnectedCount(events) == 1)
        #expect(await eventually(timeout: Self.timeout) { await client.sut.state == .notConnected })
        try await Task.sleep(for: .milliseconds(200))
        #expect(disconnectedCount(await client.states.items) == 1)

        try await client.sut.connect()
        #expect(await client.sut.state == .connected)
        #expect(await eventually(timeout: Self.timeout) { server.connectionCount == 2 })
    }

    @Test("a server close frame is forwarded with its close code")
    func serverCloseFrameIsForwardedWithCode() async throws {
        let server = try await LocalWebSocketServer.start()
        defer { server.stop() }
        let client = Client(port: server.port)

        try await client.sut.connect()
        #expect(await eventually(timeout: Self.timeout) { server.connectionCount == 1 })

        server.closeAll()

        let events = await client.states.waitForCount(3, timeout: Self.timeout)
        #expect(disconnectedCount(events) == 1)
        if case let .disconnected(closeCode, _, _) = events.last {
            #expect(closeCode == .normalClosure)
        } else {
            Issue.record("expected .disconnected, got \(String(describing: events.last))")
        }
        #expect(await eventually(timeout: Self.timeout) { await client.sut.state == .notConnected })
    }

    @Test("an on-demand disconnect resolves and forwards exactly one disconnected")
    func onDemandDisconnectResolvesAndForwardsOnce() async throws {
        let server = try await LocalWebSocketServer.start()
        defer { server.stop() }
        let client = Client(port: server.port)

        try await client.sut.connect()
        #expect(await eventually(timeout: Self.timeout) { server.connectionCount == 1 })

        try await client.sut.disconnect()

        #expect(await eventually(timeout: Self.timeout) { await client.sut.state == .notConnected })
        try await Task.sleep(for: .milliseconds(200))
        let events = await client.states.items
        #expect(disconnectedCount(events) == 1)
        if case let .disconnected(closeCode, _, _) = events.last {
            #expect(closeCode == .normalClosure)
        } else {
            Issue.record("expected .disconnected, got \(String(describing: events.last))")
        }
        await #expect(throws: WebSocketError.self) {
            try await client.sut.disconnect()
        }
    }
}
