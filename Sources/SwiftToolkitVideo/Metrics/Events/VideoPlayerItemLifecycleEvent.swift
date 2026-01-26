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

/// Events that describe item lifecycle and loading.
public enum VideoPlayerItemLifecycleEvent: Sendable {
    /// The item status changed.
    /// - Parameter status: The new status (for example, `.unknown`, `.readyToPlay`, or `.failed`).
    case statusChanged(AVPlayerItem.Status, error: Error?)
    /// The player’s reason for waiting to play changed.
    /// - Parameter reason: The new reason, or `nil` if the player is not waiting.
    case waitingReasonChanged(AVPlayer.WaitingReason?)
    /// The current player item was replaced.
    /// - Parameter item: The new item, or `nil` if the player has no item.
    case itemChanged(AVPlayerItem?)
}

// MARK: - CustomStringConvertible

extension VideoPlayerItemLifecycleEvent: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case let .statusChanged(status, error):
            switch status {
            case .unknown:
                return "Item status changed to Unknown"
            case .readyToPlay:
                return "Item status changed to Ready to play"
            case .failed:
                return "Item status changed to Failed, error: \(error?.localizedDescription, default: "nil")"
            @unknown default:
                return "Item status changed to Unknown"
            }
        case let .waitingReasonChanged(reason):
            let localizedReason: String?
            switch reason {
            case .evaluatingBufferingRate:
                localizedReason = "Evaluating buffering rate"
            case .interstitialEvent:
                localizedReason = "Interstitial event"
            case .noItemToPlay:
                localizedReason = "No item to play"
            case .toMinimizeStalls:
                localizedReason = "To minimize stalls"
            case .waitingForCoordinatedPlayback:
                localizedReason = "Waiting for coordinated playback"
            case .none, .some:
                localizedReason = nil
            }
            return "Player waiting reason changed to: \(localizedReason, default: "nil")"
        case let .itemChanged(item):
            return "Item changed to: \(String(describing: item))"
        }
    }
}
#endif
