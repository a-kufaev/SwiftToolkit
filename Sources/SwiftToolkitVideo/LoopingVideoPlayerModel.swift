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

/// Lightweight looping video model: AVQueuePlayer + AVPlayerLooper, exposes VideoPlayerMetrics.
/// Reusable for feeds, previews, etc.
@MainActor
public final class LoopingVideoPlayerModel {

    public let player: AVQueuePlayer
    public let metrics = VideoPlayerMetrics()

    /// URL of the video the model is set to play; nil before the first `setVideo` and after `reset()`.
    ///
    /// Reflects the requested video rather than the player queue: AVPlayerLooper populates the queue on its own
    /// schedule, so `player.currentItem` is still nil for a while after `setVideo` returns.
    public private(set) var currentURL: URL?

    private var looper: AVPlayerLooper?
    private var loopingItemsObservation: NSKeyValueObservation?
    private var preferredForwardBufferDuration: TimeInterval?

    public init() {
        player = AVQueuePlayer()
        metrics.bind(player)
    }

    public func setVideo(url: URL) {
        setVideo(item: AVPlayerItem(url: url))
    }

    /// Loops the specified item.
    ///
    /// The item is a template only: AVPlayerLooper plays replicas of it and never the template itself, so the template
    /// is deliberately not inserted into the queue. Enqueueing it would buffer a second copy of the same asset and
    /// make it the current item until the looper inserts the replicas ahead of it.
    public func setVideo(item: AVPlayerItem) {
        reset()
        currentURL = (item.asset as? AVURLAsset)?.url
        looper = AVPlayerLooper(player: player, templateItem: item)
        applyPreferredForwardBufferDuration()
        observeLoopingItems()
    }

    /// Sets how far ahead of the playhead to buffer, or nil to let the system decide.
    ///
    /// Applied to the replicas the looper plays, in any order relative to `setVideo`, and kept across `reset()`.
    public func setPreferredForwardBufferDuration(_ duration: TimeInterval?) {
        preferredForwardBufferDuration = duration
        applyPreferredForwardBufferDuration()
    }

    public func seek(to time: CMTime) {
        player.seek(to: time)
    }

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }

    public func reset() {
        loopingItemsObservation?.invalidate()
        loopingItemsObservation = nil
        looper?.disableLooping()
        looper = nil
        currentURL = nil
        player.pause()
        player.removeAllItems()
    }
}

// MARK: - Buffering

extension LoopingVideoPlayerModel {

    /// Properties set on the template after the looper is created are not forwarded to the replicas, so the buffer
    /// preference is re-applied whenever the looper publishes a new set of them.
    private func observeLoopingItems() {
        loopingItemsObservation = looper?.observe(\.loopingPlayerItems, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.applyPreferredForwardBufferDuration()
            }
        }
    }

    private func applyPreferredForwardBufferDuration() {
        let duration = preferredForwardBufferDuration ?? .zero
        looper?.loopingPlayerItems.forEach { $0.preferredForwardBufferDuration = duration }
    }
}
#endif
