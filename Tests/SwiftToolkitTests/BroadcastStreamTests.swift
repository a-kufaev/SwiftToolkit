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

@Suite("BroadcastStream")
struct BroadcastStreamTests {

    @Test("yielded value reaches a single subscriber")
    func yieldReachesSubscriber() async {
        let stream = BroadcastStream<Int>()
        let subscription = await stream.subscribe()
        var iterator = subscription.makeAsyncIterator()

        await stream.yield(42)

        let value = await iterator.next()
        #expect(value == 42)
    }

    @Test("multiple subscribers receive the same value")
    func yieldReachesAllSubscribers() async {
        let stream = BroadcastStream<Int>()
        let first = await stream.subscribe()
        let second = await stream.subscribe()
        var firstIter = first.makeAsyncIterator()
        var secondIter = second.makeAsyncIterator()

        await stream.yield(7)

        let firstValue = await firstIter.next()
        let secondValue = await secondIter.next()
        #expect(firstValue == 7)
        #expect(secondValue == 7)
    }

    @Test("subscriber receives values in the order they were yielded")
    func valuesArrivedInOrder() async {
        let stream = BroadcastStream<Int>()
        let subscription = await stream.subscribe()
        var iterator = subscription.makeAsyncIterator()

        await stream.yield(1)
        await stream.yield(2)
        await stream.yield(3)

        let first = await iterator.next()
        let second = await iterator.next()
        let third = await iterator.next()
        #expect(first == 1)
        #expect(second == 2)
        #expect(third == 3)
    }

    @Test("unsubscribe finishes the stream")
    func unsubscribeFinishesStream() async {
        let stream = BroadcastStream<Int>()
        let id = UUID()
        let subscription = await stream.subscribe(id: id)
        var iterator = subscription.makeAsyncIterator()

        await stream.unsubscribe(id: id)

        let value = await iterator.next()
        #expect(value == nil)
    }

    @Test("late subscriber does not receive past values")
    func lateSubscriberSkipsPastValues() async {
        let stream = BroadcastStream<Int>()

        await stream.yield(1)
        await stream.yield(2)
        let subscription = await stream.subscribe()
        var iterator = subscription.makeAsyncIterator()
        await stream.yield(3)

        let value = await iterator.next()
        #expect(value == 3)
    }
}
