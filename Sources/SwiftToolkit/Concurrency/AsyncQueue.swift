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

/// A serial queue for asynchronous work, backed by an `AsyncStream`.
///
/// Tasks are executed one after another in FIFO order. Use `enqueue(_:)` for fire-and-forget work,
/// or `enqueueAndWait(_:)` to suspend until the enqueued task completes (and to receive its result).
///
/// ## Example
/// ```swift
/// let queue = AsyncQueue()
///
/// queue.enqueue {
///     await step1()
/// }
///
/// let result = await queue.enqueueAndWait {
///     await step2()
/// }
/// ```
public final class AsyncQueue: Sendable {
    private let taskStreamContinuation: AsyncStream<@Sendable () async -> Void>.Continuation

    public init(priority: TaskPriority? = nil) {
        let (taskStream, taskStreamContinuation) = AsyncStream<@Sendable () async -> Void>.makeStream()
        self.taskStreamContinuation = taskStreamContinuation

        Task.detached(priority: priority) {
            for await task in taskStream {
                await task()
            }
        }
    }

    deinit {
        taskStreamContinuation.finish()
    }

    public func enqueue(_ task: @escaping @Sendable () async -> Void) {
        taskStreamContinuation.yield(task)
    }

    public func enqueue<ActorType: Actor>(
        on isolatedActor: ActorType,
        _ task: @escaping @Sendable (isolated ActorType) async -> Void
    ) {
        taskStreamContinuation.yield { await task(isolatedActor) }
    }

    public func enqueueAndWait<T: Sendable>(_ task: @escaping @Sendable () async -> T) async -> T {
        await withUnsafeContinuation { continuation in
            taskStreamContinuation.yield {
                await continuation.resume(returning: task())
            }
        }
    }

    public func enqueueAndWait<ActorType: Actor, T: Sendable>(
        on isolatedActor: isolated ActorType,
        _ task: @escaping @Sendable (isolated ActorType) async -> T
    ) async -> T {
        await withUnsafeContinuation { continuation in
            taskStreamContinuation.yield {
                await continuation.resume(returning: task(isolatedActor))
            }
        }
    }

    public func enqueueAndWait<T: Sendable>(_ task: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            taskStreamContinuation.yield {
                do {
                    try await continuation.resume(returning: task())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func enqueueAndWait<ActorType: Actor, T: Sendable>(
        on isolatedActor: isolated ActorType,
        _ task: @escaping @Sendable (isolated ActorType) async throws -> T
    ) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            taskStreamContinuation.yield {
                do {
                    try await continuation.resume(returning: task(isolatedActor))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
