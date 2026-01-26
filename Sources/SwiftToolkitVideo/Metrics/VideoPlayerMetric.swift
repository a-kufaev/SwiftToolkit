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

/// A unified event type for all video player metrics.
///
/// Switch on the associated value to handle timeline, item lifecycle, buffer, or ABR events.
public enum VideoPlayerMetric: Sendable {
    /// A timeline event (time control, duration, position, rate, ended, stalled, or failed).
    case timeline(VideoPlayerTimelineEvent)
    /// An item lifecycle event (status, waiting reason, or item change).
    case itemLifecycle(VideoPlayerItemLifecycleEvent)
    /// A buffer event (empty, full, likelyToKeepUp, or progress update).
    case buffer(VideoPlayerBufferEvent)
}

// MARK: - CustomStringConvertible

extension VideoPlayerMetric: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case let .timeline(videoPlayerTimelineEvent):
            videoPlayerTimelineEvent.description
        case let .itemLifecycle(videoPlayerItemLifecycleEvent):
            videoPlayerItemLifecycleEvent.description
        case let .buffer(videoPlayerBufferEvent):
            videoPlayerBufferEvent.description
        }
    }
}
#endif
