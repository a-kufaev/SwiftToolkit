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

/// The phase of a data-loading lifecycle managed by a ``DataStore``.
public enum LoadingPhase: Sendable, Equatable, Hashable {

    /// No load has been requested yet.
    case idle
    /// A load is in progress and there is no content to show yet.
    case loading
    /// Content has been loaded successfully.
    case loaded
    /// Loading failed and there is no content to show.
    case error
}
