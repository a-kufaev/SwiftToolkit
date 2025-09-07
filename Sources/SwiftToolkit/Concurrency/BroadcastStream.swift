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

/// An actor-based publish/subscribe stream that fans a single event out to many subscribers.
///
/// Each subscriber receives its own `AsyncStream`. Subscribers whose continuation is dropped or
/// terminated are pruned automatically on the next `yield(_:)`.
///
/// ## Example
/// ```swift
/// let broadcast = BroadcastStream<Int>()
///
/// Task {
///     for await value in await broadcast.subscribe() {
///         print(value)
///     }
/// }
///
/// await broadcast.yield(42)
/// ```
public actor BroadcastStream<Event: Sendable> {

    // MARK: - Storage

    private var subscribers: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

    // MARK: - Subscription

    public func subscribe(id: UUID = UUID()) -> AsyncStream<Event> {
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        subscribers[id] = continuation
        return stream
    }

    public func unsubscribe(id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }

    // MARK: - Event Emission

    public func yield(_ event: Event) {
        for (id, continuation) in subscribers {
            let result = continuation.yield(event)
            switch result {
            case .enqueued:
                continue
            case .dropped, .terminated:
                unsubscribe(id: id)
            @unknown default:
                unsubscribe(id: id)
            }
        }
    }
}
