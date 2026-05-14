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

@Suite("AsyncQueue")
struct AsyncQueueTests {

    @Test("enqueue runs tasks in FIFO order")
    func runsTasksInOrder() async {
        let queue = AsyncQueue()
        let order = CapturedOrder()

        await queue.enqueueAndWait { await order.append("a") }
        await queue.enqueueAndWait { await order.append("b") }
        await queue.enqueueAndWait { await order.append("c") }

        await #expect(order.values == ["a", "b", "c"])
    }

    @Test("enqueueAndWait returns the value the task produced")
    func returnsValueFromTask() async {
        let queue = AsyncQueue()

        let result = await queue.enqueueAndWait { 42 }

        #expect(result == 42)
    }

    @Test("enqueueAndWait rethrows errors from the task")
    func rethrowsError() async {
        let queue = AsyncQueue()

        await #expect(throws: SampleError.self) {
            _ = try await queue.enqueueAndWait { throw SampleError.boom }
        }
    }
}

private enum SampleError: Error {
    case boom
}

private actor CapturedOrder {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}
