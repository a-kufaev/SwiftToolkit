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

/// Load state of the image in `AdaptiveImageView`, reported via `onLoadStatusChange`.
public enum AdaptiveImageLoadStatus: Equatable, Sendable {
    /// No image to load (e.g. empty variants).
    case idle
    /// Target image is being loaded (placeholder may be visible if a lower‑res variant is cached).
    case loading
    /// Target image has been loaded and displayed.
    case loaded
    /// Load failed. Associated error when available from the loader.
    case failure(Error? = nil)

    public static func == (lhs: AdaptiveImageLoadStatus, rhs: AdaptiveImageLoadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
            return true
        case let (.failure(lhsError), .failure(rhsError)):
            return (lhsError as NSError?)?.domain == (rhsError as NSError?)?.domain
                && (lhsError as NSError?)?.code == (rhsError as NSError?)?.code
        default:
            return false
        }
    }
}
