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
/// The buffer state of the current item, as reported by `VideoPlayerMetrics`.
public enum VideoBufferState {
    /// No data is buffered; playback may stall.
    case empty
    /// Data is being buffered.
    case buffering
    /// Enough data is buffered to continue playback (playbackLikelyToKeepUp).
    case likelyToKeepUp
    /// The buffer is full (playbackBufferFull).
    case full
}
#endif
