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

/// An observable container that owns a single piece of asynchronously-loaded `Content`
/// together with its loading `phase` and last error.
///
/// A `DataStore` is the single source of truth for one resource. SwiftUI views observe it directly
/// (it is `Observable`) and drive UI off `phase` / `content` / `lastError`.
@MainActor
public protocol DataStore: Observable {

    associatedtype Content: Sendable

    var phase: LoadingPhase { get }
    var content: Content? { get }
    var lastError: Error? { get }

    /// Whether the current `content` is considered stale (e.g. an underlying repository cache expired).
    ///
    /// Defaults to `false` — "no special check, trust whatever is in `content`".
    /// A concrete store overrides this and queries the underlying layer (a repository with a TTL,
    /// a version from a service, etc.) so that the decision to refresh `content` is made by this
    /// channel rather than by a timer in the UI.
    var isContentStale: Bool { get async }

    @discardableResult
    func load(force: Bool) async throws -> Content
    func reset()
}

// MARK: - Convenience Extension

extension DataStore {

    @discardableResult
    public func load() async throws -> Content {
        try await load(force: false)
    }

    /// Default implementation — treats `content` as never stale.
    /// Override it in stores whose freshness is verified externally (e.g. by a repository cache).
    public var isContentStale: Bool {
        get async { false }
    }
}
