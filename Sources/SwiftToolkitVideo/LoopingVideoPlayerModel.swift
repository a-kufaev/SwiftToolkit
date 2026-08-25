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

/// Lightweight looping video model: a single AVPlayer that seeks back to zero at end, exposes VideoPlayerMetrics.
/// Reusable for feeds, previews, etc.
///
/// Deliberately not AVPlayerLooper: the looper plays replicas of a template item, which churns `currentItem`
/// (breaking KVO-driven consumers), holds two decode sessions per player, re-buffers HLS on every cycle, and
/// swallows template-asset failures so the item never reports `.failed`. One stable item keeps its status and
/// errors observable and loops from its own buffer.
@MainActor
public final class LoopingVideoPlayerModel {

    public let player: AVPlayer
    public let metrics = VideoPlayerMetrics()

    /// URL of the video the model is set to play; nil before the first `setVideo` and after `reset()`.
    public private(set) var currentURL: URL?

    private var loopTask: Task<Void, Never>?
    private var preferredForwardBufferDuration: TimeInterval?

    public init() {
        player = AVPlayer()
        // The loop seeks while the rate is still up; pausing at end would add a stop-start seam every cycle.
        player.actionAtItemEnd = .none
        metrics.bind(player)
    }

    @MainActor
    deinit {
        loopTask?.cancel()
    }

    public func setVideo(url: URL) {
        setVideo(item: AVPlayerItem(url: url))
    }

    /// Loops the specified item.
    public func setVideo(item: AVPlayerItem) {
        reset()
        currentURL = (item.asset as? AVURLAsset)?.url
        applyPreferredForwardBufferDuration(to: item)
        player.replaceCurrentItem(with: item)
        observeEnd(of: item)
    }

    /// Sets how far ahead of the playhead to buffer, or nil to let the system decide.
    ///
    /// Applied to the current item, in any order relative to `setVideo`, and kept across `reset()`.
    public func setPreferredForwardBufferDuration(_ duration: TimeInterval?) {
        preferredForwardBufferDuration = duration
        if let item = player.currentItem {
            applyPreferredForwardBufferDuration(to: item)
        }
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
        loopTask?.cancel()
        loopTask = nil
        currentURL = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}

// MARK: - Looping

extension LoopingVideoPlayerModel {

    private func observeEnd(of item: AVPlayerItem) {
        loopTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
            for await _ in notifications {
                guard let self else { return }
                // Position zero is a keyframe, so the exact seek costs nothing and cannot land mid-clip.
                await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
}

// MARK: - Buffering

extension LoopingVideoPlayerModel {

    private func applyPreferredForwardBufferDuration(to item: AVPlayerItem) {
        item.preferredForwardBufferDuration = preferredForwardBufferDuration ?? .zero
    }
}
#endif
