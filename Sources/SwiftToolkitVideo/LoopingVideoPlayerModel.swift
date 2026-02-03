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

    public var currentURL: URL? { (player.currentItem?.asset as? AVURLAsset)?.url }

    private var looper: AVPlayerLooper?

    public init() {
        player = AVQueuePlayer()
        metrics.bind(player)
    }

    public func setVideo(url: URL) {
        setVideo(item: AVPlayerItem(url: url))
    }

    public func setVideo(item: AVPlayerItem) {
        reset()
        player.insert(item, after: nil)
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    public func setPreferredForwardBufferDuration(_ duration: TimeInterval?) {
        player.currentItem?.preferredForwardBufferDuration = duration ?? .zero
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
        looper?.disableLooping()
        looper = nil
        player.pause()
        player.removeAllItems()
    }
}
#endif
