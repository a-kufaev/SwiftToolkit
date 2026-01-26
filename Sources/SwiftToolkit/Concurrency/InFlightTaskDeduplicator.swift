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

/// Deduplicates concurrent tasks by key.
///
/// If a task with the same key is already running, a subsequent `run` awaits its result instead of
/// starting a new task. Useful for preventing duplicate network requests and heavy operations.
public actor InFlightTaskDeduplicator<Value: Sendable> {

    /// The currently running tasks, keyed by their deduplication key.
    public private(set) var tasks: [AnyHashable: Task<Value, Error>] = [:]

    public init() {}

    /// Runs an operation, deduplicating by key.
    ///
    /// - Parameters:
    ///   - key: The task key; matching keys are coalesced into a single task.
    ///   - operation: The asynchronous operation to run.
    /// - Returns: The result of the operation (either its own, or the already-running one with the same key).
    public func run(
        key: AnyHashable,
        operation: @Sendable @escaping () async throws -> Value
    ) async throws -> Value {
        if let task = tasks[key] {
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        tasks[key] = task

        defer { tasks[key] = nil }
        return try await task.value
    }
}
