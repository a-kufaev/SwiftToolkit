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

struct TestError: Error, Equatable {
    let id: Int

    init(_ id: Int = 0) {
        self.id = id
    }
}

/// A `WebSocketConnection` the test drives by hand: it decides what `state` reports and in which order the two
/// streams end, so every teardown interleaving `ReconnectableWebSocket` must survive can be produced on demand.
actor FakeWebSocketConnection: WebSocketConnection {

    enum FailureOrder: CaseIterable {
        case stateFirst
        case messagesFirst
    }

    nonisolated let messages: AsyncThrowingStream<WebSocket.Message, Error>
    nonisolated let stateEvents: AsyncStream<WebSocket.StateChangedEvent>

    private(set) var state: WebSocket.State = .notConnected
    private(set) var connectCalls = 0
    private(set) var sent: [String] = []

    private let messagesContinuation: AsyncThrowingStream<WebSocket.Message, Error>.Continuation
    private let stateEventsContinuation: AsyncStream<WebSocket.StateChangedEvent>.Continuation
    private let connectError: Error?
    private var heldEvent: WebSocket.StateChangedEvent?

    init(connectError: Error? = nil) {
        let (messages, messagesContinuation) = AsyncThrowingStream.makeStream(
            of: WebSocket.Message.self,
            throwing: Error.self
        )
        self.messages = messages
        self.messagesContinuation = messagesContinuation

        let (stateEvents, stateEventsContinuation) = AsyncStream.makeStream(of: WebSocket.StateChangedEvent.self)
        self.stateEvents = stateEvents
        self.stateEventsContinuation = stateEventsContinuation

        self.connectError = connectError
    }

    // MARK: - WebSocketConnection

    func connect() async throws {
        connectCalls += 1
        state = .connecting
        stateEventsContinuation.yield(.connecting)

        if let connectError {
            state = .disconnected
            stateEventsContinuation.finish()
            messagesContinuation.finish()
            throw connectError
        }

        state = .connected
        stateEventsContinuation.yield(.connected)
    }

    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: String?) async throws {
        guard state == .connected else {
            throw WebSocketError.notConnected
        }
        close(code: closeCode, reason: reason)
    }

    func send(_ value: any Encodable) async throws {
        let data = try JSONEncoder().encode(value)
        try await send(String(decoding: data, as: UTF8.self))
    }

    func send(_ string: String) async throws {
        guard state == .connected else {
            throw WebSocketError.notConnected
        }
        sent.append(string)
    }

    // MARK: - Test controls

    func receive(_ message: WebSocket.Message) {
        messagesContinuation.yield(message)
    }

    /// A server-initiated close: `.disconnected` with a close code, both streams finish normally.
    func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: String? = nil) {
        guard state == .connected else { return }
        state = .disconnected
        stateEventsContinuation.yield(.disconnected(closeCode: code, reason: reason, error: nil))
        stateEventsContinuation.finish()
        messagesContinuation.finish()
    }

    /// A transport error: `.disconnected` carrying `error`, `messages` finishes throwing. `order` decides which
    /// stream ends first, mirroring the two callback orders URLSession produces.
    func fail(_ error: Error, order: FailureOrder = .stateFirst) async {
        state = .disconnected
        switch order {
        case .stateFirst:
            stateEventsContinuation.yield(.disconnected(closeCode: nil, reason: nil, error: error))
            stateEventsContinuation.finish()
            messagesContinuation.finish(throwing: error)
        case .messagesFirst:
            messagesContinuation.finish(throwing: error)
            await Task.yield()
            stateEventsContinuation.yield(.disconnected(closeCode: nil, reason: nil, error: error))
            stateEventsContinuation.finish()
        }
    }

    /// Finishes `messages` with `error` but keeps the `.disconnected` event back until `releaseStateEvent()`.
    func failHoldingStateEvent(_ error: Error) {
        state = .disconnected
        heldEvent = .disconnected(closeCode: nil, reason: nil, error: error)
        messagesContinuation.finish(throwing: error)
    }

    func releaseStateEvent() {
        guard let heldEvent else { return }
        self.heldEvent = nil
        stateEventsContinuation.yield(heldEvent)
        stateEventsContinuation.finish()
    }
}

/// Hands out pre-built fakes to `ReconnectableWebSocket`'s connection factory, one per `connect()`.
final class FakeConnectionQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [FakeWebSocketConnection]

    init(_ items: [FakeWebSocketConnection]) {
        self.items = items
    }

    var remaining: Int {
        lock.withLock { items.count }
    }

    func next() -> FakeWebSocketConnection {
        lock.withLock { items.removeFirst() }
    }
}

/// Suspends callers until opened; lets a test park `connect()` inside its `connector` call.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var waiterCount: Int {
        waiters.count
    }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let waiters = self.waiters
        self.waiters = []
        waiters.forEach { $0.resume() }
    }
}

/// Collects everything a stream yields for the lifetime of a test, so assertions can be made about counts and
/// order without competing with the single consumer slot of an `AsyncStream`.
actor EventLog<Element: Sendable> {
    private(set) var items: [Element] = []

    func append(_ item: Element) {
        items.append(item)
    }

    func waitForCount(_ count: Int, timeout: Duration = .seconds(2)) async -> [Element] {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while items.count < count, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        return items
    }
}

struct SocketHarness {
    let sut: ReconnectableWebSocket
    let queue: FakeConnectionQueue
    let states: EventLog<WebSocket.StateChangedEvent>
    let observer: Task<Void, Never>

    init(_ fakes: [FakeWebSocketConnection], gate: Gate? = nil) {
        let queue = FakeConnectionQueue(fakes)
        let states = EventLog<WebSocket.StateChangedEvent>()
        let sut = ReconnectableWebSocket(
            connector: {
                await gate?.wait()
                return URLRequest(url: URL(string: "wss://example.invalid")!)
            },
            makeConnection: { _ in queue.next() }
        )
        self.sut = sut
        self.queue = queue
        self.states = states
        observer = Task {
            for await event in sut.stateEvents {
                await states.append(event)
            }
        }
    }
}

func disconnectedCount(_ events: [WebSocket.StateChangedEvent]) -> Int {
    events.filter { event in
        if case .disconnected = event { return true }
        return false
    }.count
}

func eventually(
    timeout: Duration = .seconds(2),
    _ condition: @Sendable () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return await condition()
}
