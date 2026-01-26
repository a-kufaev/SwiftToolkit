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

#if canImport(UIKit)
/// The load state of the current player item, as reported by `VideoPlayerMetrics`.
public enum VideoItemState {
    /// No item is set, or the item has not started loading.
    case idle
    /// The item is loading (AVPlayerItem status is unknown).
    case preparing
    /// The item is ready to play; safe to call `play()`.
    case readyToPlay
    /// The item failed to load or play.
    case failed
}
#endif
