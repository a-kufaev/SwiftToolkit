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

/// A lightweight one-way event signal built on top of `AsyncStream`.
///
/// `AsyncSignal` is both the producer and the sequence: send values with `send(_:)`, terminate
/// with `finish()`, and consume them with `for await`.
///
/// ## Example
/// ```swift
/// let signal = AsyncSignal(of: Int.self)
///
/// Task {
///     for await value in signal {
///         print(value)
///     }
/// }
///
/// signal.send(1)
/// signal.send(2)
/// signal.finish()
/// ```
public struct AsyncSignal<Element: Sendable>: AsyncSequence, Sendable {

    public typealias Element = Element
    public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator

    public let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation

    public init(
        of elementType: Element.Type = Element.self,
        bufferingPolicy limit: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) {
        let (stream, continuation) = AsyncStream<Element>.makeStream(
            of: elementType,
            bufferingPolicy: limit
        )
        self.stream = stream
        self.continuation = continuation
    }

    public func send(_ element: Element) {
        continuation.yield(element)
    }

    public func finish() {
        continuation.finish()
    }

    public func makeAsyncIterator() -> AsyncStream<Element>.AsyncIterator {
        stream.makeAsyncIterator()
    }
}
