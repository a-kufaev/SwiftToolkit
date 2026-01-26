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

/// Debounces asynchronous work: each call to `debounce(task:)` cancels the previously scheduled
/// task and re-schedules a new one after the configured delay.
///
/// Useful for search-as-you-type, live validation, or any rapidly repeated trigger where only the
/// last invocation should run.
///
/// ## Example
/// ```swift
/// let debouncer = TaskDebouncer(seconds: 0.3)
///
/// func searchTextChanged(_ query: String) {
///     debouncer.debounce {
///         await performSearch(query)
///     }
/// }
/// ```
public final class TaskDebouncer: @unchecked Sendable {

    private let seconds: TimeInterval
    private var task: Task<Void, Never>?

    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    public func debounce(task: @Sendable @escaping () async -> Void) {
        self.task?.cancel()
        self.task = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if Task.isCancelled {
                return
            }
            await task()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
