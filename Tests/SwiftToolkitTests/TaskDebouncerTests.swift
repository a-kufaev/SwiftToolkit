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

@Suite("TaskDebouncer")
struct TaskDebouncerTests {

    @Test("runs the task after the configured delay")
    func runsTaskAfterDelay() async throws {
        let debouncer = TaskDebouncer(seconds: 0.05)
        let signal = OneShotSignal()

        debouncer.debounce {
            await signal.send()
        }

        await signal.wait()
    }

    @Test("cancel prevents the task from running")
    func cancelPreventsExecution() async throws {
        let debouncer = TaskDebouncer(seconds: 0.05)
        let counter = CapturedCount()
        debouncer.debounce { await counter.increment() }

        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(150))

        await #expect(counter.value == 0)
    }

    @Test("only the last scheduled task runs when called rapidly")
    func onlyLastTaskRuns() async throws {
        let debouncer = TaskDebouncer(seconds: 0.05)
        let firstCalled = CapturedCount()
        let secondCalled = CapturedCount()

        debouncer.debounce { await firstCalled.increment() }
        debouncer.debounce { await secondCalled.increment() }
        try await Task.sleep(for: .milliseconds(150))

        await #expect(firstCalled.value == 0)
        await #expect(secondCalled.value == 1)
    }
}

private actor CapturedCount {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor OneShotSignal {
    private var continuation: CheckedContinuation<Void, Never>?
    private var fired = false

    func wait() async {
        if fired { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func send() {
        fired = true
        continuation?.resume()
        continuation = nil
    }
}
