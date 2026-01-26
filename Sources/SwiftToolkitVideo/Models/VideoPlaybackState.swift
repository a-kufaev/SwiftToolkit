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
/// The playback control state of the player, as reported by `VideoPlayerMetrics`.
public enum VideoPlaybackState {
    /// No item is loaded, or the state is not yet determined.
    case idle
    /// The player is actively playing.
    case playing
    /// The player is paused (by user or programmatically).
    case paused
    /// The player is waiting to start (for example, while buffering). See `waitingToPlayReason`.
    case waitingToPlay
    /// Playback has stalled because the buffer is empty.
    case stalled
    /// Playback reached the end (one cycle when using a looper).
    case ended
    /// Playback failed before reaching the end (for example, a network or decoding error).
    case failedToPlayToEnd
}
#endif
