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

import Observation

/// A ready-to-subclass ``DataStore`` that implements the loading lifecycle using the
/// template-method pattern: subclasses only override ``fetch(force:)``.
///
/// `load(force:)` switches to `.loading` only when there is no existing `content`, so refreshes are
/// silent when data is already on screen. On failure it preserves existing content (keeping `.loaded`)
/// and records `lastError`; only the first load with no content transitions to `.error`.
@MainActor @Observable
open class AsyncDataStore<Content: Sendable>: DataStore {

    public private(set) var phase: LoadingPhase = .idle
    public private(set) var content: Content?
    public private(set) var lastError: Error?

    public init() {}

    open func fetch(force _: Bool) async throws -> Content {
        fatalError("Override in subclass")
    }

    /// Override if the store has an underlying source whose freshness can be checked
    /// (e.g. a repository cache TTL). Defaults to `false`.
    open var isContentStale: Bool {
        get async { false }
    }

    public final func load(force: Bool) async throws -> Content {
        if content == nil {
            phase = .loading
        }

        do {
            let content = try await fetch(force: force)
            self.content = content
            phase = .loaded
            lastError = nil
            return content
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            lastError = error
            if content == nil {
                phase = .error
            }
            throw error
        }
    }

    public final func set(_ content: Content) {
        self.content = content
        phase = .loaded
    }

    public final func reset() {
        content = nil
        phase = .idle
        lastError = nil
    }
}
