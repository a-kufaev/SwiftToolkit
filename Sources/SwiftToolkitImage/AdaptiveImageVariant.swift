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

import CoreGraphics
import Foundation

/// A single resolution variant of an image (URL + size). Used by `AdaptiveImageView` to pick the best variant for the
/// target size and to show a cached lower-res image as a placeholder.
public struct AdaptiveImageVariant: Hashable, Sendable {
    public let url: URL
    public let size: CGSize

    public init(url: URL, size: CGSize) {
        self.url = url
        self.size = size
    }
}
