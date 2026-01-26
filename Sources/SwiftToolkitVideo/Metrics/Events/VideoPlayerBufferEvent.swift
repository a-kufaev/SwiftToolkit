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
import Foundation

/// Events that describe buffer state and load progress.
public enum VideoPlayerBufferEvent: Sendable, Equatable {
    /// The buffer is empty; playback may stall.
    case bufferEmpty
    /// The buffer is full.
    case bufferFull
    /// Enough data is buffered to keep playing (playbackLikelyToKeepUp).
    case likelyToKeepUp
    /// The buffer and load progress updated (from loadedTimeRanges and duration).
    /// - Parameters:
    ///   - secondsInBuffer: The number of seconds of content buffered ahead of the playhead.
    ///   - percentage: The loaded portion of the video, from 0 to 100.
    case bufferUpdated(secondsInBuffer: TimeInterval, percentage: Double)
}

// MARK: - CustomStringConvertible

extension VideoPlayerBufferEvent: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .bufferEmpty:
            "Buffer is empty"
        case .bufferFull:
            "Buffer is full"
        case .likelyToKeepUp:
            "Buffer likely to keep up"
        case let .bufferUpdated(secondsInBuffer, percentage):
            "Buffer updated: \(secondsInBuffer)s in buffer (\(percentage)%)"
        }
    }
}
#endif
