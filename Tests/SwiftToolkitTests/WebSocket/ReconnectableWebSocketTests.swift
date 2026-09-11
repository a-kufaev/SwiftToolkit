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

@Suite("ReconnectableWebSocket")
struct ReconnectableWebSocketTests {

    @Test("an error disconnect is forwarded once and the connection is retired")
    func errorDisconnectIsForwardedAndSocketRetired() async throws {
        let first = FakeWebSocketConnection()
        let second = FakeWebSocketConnection()
        let harness = SocketHarness([first, second])

        try await harness.sut.connect()
        #expect(await harness.sut.state == .connected)

        await first.fail(TestError())

        let events = await harness.states.waitForCount(3)
        #expect(events.count == 3)
        #expect(disconnectedCount(events) == 1)
        if case let .disconnected(closeCode, _, error) = events[2] {
            #expect(closeCode == nil)
            #expect(error as? TestError == TestError())
        } else {
            Issue.record("expected .disconnected, got \(events[2])")
        }
        #expect(await eventually { await harness.sut.state == .notConnected })

        try await harness.sut.connect()
        #expect(await second.connectCalls == 1)
        #expect(await harness.sut.state == .connected)
        #expect(harness.queue.remaining == 0)
    }

    @Test("the disconnect survives both stream orders", arguments: 0 ..< 100)
    func disconnectSurvivesBothOrders(iteration: Int) async throws {
        let order: FakeWebSocketConnection.FailureOrder = iteration.isMultiple(of: 2) ? .stateFirst : .messagesFirst
        let fake = FakeWebSocketConnection()
        let harness = SocketHarness([fake])

        try await harness.sut.connect()
        await fake.fail(TestError(iteration), order: order)

        let events = await harness.states.waitForCount(3)
        #expect(disconnectedCount(events) == 1, "iteration \(iteration), order \(order)")
        #expect(await eventually { await harness.sut.state == .notConnected }, "iteration \(iteration)")
        await #expect(throws: WebSocketError.self) {
            try await harness.sut.send("x")
        }
        #expect(await fake.sent.isEmpty)
        harness.observer.cancel()
    }

    @Test("a normal close is forwarded with its code and the connection is retired")
    func normalCloseIsForwardedAndSocketRetired() async throws {
        let fake = FakeWebSocketConnection()
        let harness = SocketHarness([fake])

        try await harness.sut.connect()
        await fake.close(code: .normalClosure)

        let events = await harness.states.waitForCount(3)
        #expect(events.last == .disconnected(closeCode: .normalClosure, reason: nil, error: nil))
        #expect(await eventually { await harness.sut.state == .notConnected })
    }

    @Test("a late disconnect of a retired connection cannot retire the newer one")
    func staleForwarderCannotRetireNewerConnection() async throws {
        let first = FakeWebSocketConnection()
        let second = FakeWebSocketConnection()
        let harness = SocketHarness([first, second])

        try await harness.sut.connect()
        await first.failHoldingStateEvent(TestError())
        #expect(await harness.sut.state == .disconnected)

        try await harness.sut.connect()
        #expect(await harness.sut.state == .connected)

        await first.releaseStateEvent()

        let events = await harness.states.waitForCount(5)
        #expect(disconnectedCount(events) == 1)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await harness.sut.state == .connected)
        #expect(await second.connectCalls == 1)
    }

    @Test("concurrent connects open exactly one connection")
    func concurrentConnectOpensOneConnection() async throws {
        let gate = Gate()
        let first = FakeWebSocketConnection()
        let second = FakeWebSocketConnection()
        let harness = SocketHarness([first, second], gate: gate)

        let attempts = [
            Task { try await harness.sut.connect() },
            Task { try await harness.sut.connect() },
        ]
        #expect(await eventually { await gate.waiterCount == 1 })
        await gate.open()

        var failures: [WebSocketError] = []
        for attempt in attempts {
            if case let .failure(error) = await attempt.result, let error = error as? WebSocketError {
                failures.append(error)
            }
        }
        #expect(failures.count == 1)
        if case .alreadyConnectedOrConnecting = failures.first {} else {
            Issue.record("expected alreadyConnectedOrConnecting, got \(failures)")
        }
        #expect(await first.connectCalls == 1)
        #expect(harness.queue.remaining == 1)
        #expect(await harness.sut.state == .connected)
    }

    @Test("an on-demand disconnect forwards exactly one disconnected")
    func onDemandDisconnectForwardsExactlyOneDisconnected() async throws {
        let fake = FakeWebSocketConnection()
        let harness = SocketHarness([fake])

        try await harness.sut.connect()
        try await harness.sut.disconnect()

        let events = await harness.states.waitForCount(3)
        try await Task.sleep(for: .milliseconds(50))
        #expect(disconnectedCount(await harness.states.items) == 1)
        #expect(events.last == .disconnected(closeCode: .normalClosure, reason: nil, error: nil))
        #expect(await eventually { await harness.sut.state == .notConnected })
        await #expect(throws: WebSocketError.self) {
            try await harness.sut.disconnect()
        }
    }

    @Test("a failed connect finishes the streams and allows a fresh connect")
    func failedConnectFinishesStreamsAndAllowsReconnect() async throws {
        let first = FakeWebSocketConnection(connectError: TestError(1))
        let second = FakeWebSocketConnection()
        let harness = SocketHarness([first, second])

        await #expect(throws: TestError.self) {
            try await harness.sut.connect()
        }
        #expect(await harness.sut.state == .disconnected)
        let events = await harness.states.waitForCount(1)
        #expect(events == [.connecting])

        try await harness.sut.connect()
        #expect(await harness.sut.state == .connected)
        let all = await harness.states.waitForCount(3)
        #expect(all == [.connecting, .connecting, .connected])
        #expect(disconnectedCount(all) == 0)
    }

    @Test("a send after a retire throws instead of succeeding silently")
    func sendAfterRetireThrows() async throws {
        let fake = FakeWebSocketConnection()
        let harness = SocketHarness([fake])

        try await harness.sut.connect()
        try await harness.sut.send("before")
        await fake.fail(TestError())
        #expect(await eventually { await harness.sut.state == .notConnected })

        await #expect(throws: WebSocketError.self) {
            try await harness.sut.send("after")
        }
        #expect(await fake.sent == ["before"])
    }

    @Test("messages keep flowing through the lifetime stream across reconnects")
    func messagesAreForwardedAcrossReconnects() async throws {
        let first = FakeWebSocketConnection()
        let second = FakeWebSocketConnection()
        let harness = SocketHarness([first, second])
        var messages = harness.sut.messages.makeAsyncIterator()

        try await harness.sut.connect()
        await first.receive(.string("1"))
        guard case let .string(one) = await messages.next() else {
            Issue.record("expected a string message")
            return
        }
        #expect(one == "1")

        await first.fail(TestError())
        #expect(await eventually { await harness.sut.state == .notConnected })

        try await harness.sut.connect()
        await second.receive(.string("2"))
        guard case let .string(two) = await messages.next() else {
            Issue.record("expected a string message")
            return
        }
        #expect(two == "2")
    }
}
