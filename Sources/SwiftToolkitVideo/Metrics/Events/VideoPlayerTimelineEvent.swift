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
import AVKit
import Foundation

/// Events that describe playback timeline and control changes.
public enum VideoPlayerTimelineEvent: Sendable {
    /// The time control status changed.
    /// - Parameter status: The new status (for example, `.playing`, `.waitingToPlayAtSpecifiedRate`, or `.paused`).
    case timeControlStatusChanged(AVPlayer.TimeControlStatus)
    /// The duration of the current item became known or changed.
    /// - Parameter duration: The duration, in seconds.
    case durationUpdated(TimeInterval)
    /// The playhead position updated (for example, from a periodic time observer).
    /// - Parameter seconds: The current time, in seconds.
    case currentTimeUpdated(TimeInterval)
    /// The playback rate changed.
    /// - Parameter rate: The rate (1.0 is normal, 0 is paused).
    case rateUpdated(Float)
    /// Playback stalled because the buffer is empty and the player is waiting for data.
    case stalled
    /// One playback cycle ended (for a looper, the end of one pass before the next).
    case ended
    /// The player failed to play to the end (for example, a network or decoding error).
    case failedToPlayToEnd
}

// MARK: - CustomStringConvertible

extension VideoPlayerTimelineEvent: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case let .timeControlStatusChanged(status):
            switch status {
            case .paused:
                "Playback paused"
            case .waitingToPlayAtSpecifiedRate:
                "Playback waiting to play"
            case .playing:
                "Playback playing"
            @unknown default:
                "Playback in unknown status"
            }
        case let .durationUpdated(duration):
            "Duration: \(duration) seconds"
        case let .currentTimeUpdated(time):
            "Current time: \(time) seconds"
        case let .rateUpdated(rate):
            "Playback rate changed to: \(rate)"
        case .stalled:
            "Playback stalled"
        case .ended:
            "Playback ended"
        case .failedToPlayToEnd:
            "Playback failed to play to end"
        }
    }
}
#endif
