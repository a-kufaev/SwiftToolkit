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
import SwiftToolkit

/// Aggregates playback, buffer, timeline, and ABR metrics from a single AVPlayer.
/// Bind to a player via bind(_:); metrics update reactively. Call unbind() when done.
@MainActor
@Observable
public final class VideoPlayerMetrics {
    
    // MARK: - Playback
    
    /// The current playback state of the player (playing, paused, waiting, and so on).
    public var playbackState: VideoPlaybackState = .idle
    /// The reason the player is waiting to play, if any (for example, evaluatingBuffering).
    public var waitingToPlayReason: AVPlayer.WaitingReason?
    /// The time, in seconds, from transitioning to playing until the first frame appears. Reset when the item changes.
    public var timeToFirstFrame: TimeInterval?
    
    // MARK: - Item / Loading
    
    /// The load state of the current item (idle, preparing, readyToPlay, or failed).
    public var itemState: VideoItemState = .idle
    /// The time, in seconds, from load start until the item is ready to play. Set when status becomes readyToPlay.
    public var timeToReady: TimeInterval?
    
    // MARK: - Buffer
    
    /// The buffer state (empty, buffering, likelyToKeepUp, or full).
    public var bufferState: VideoBufferState = .empty
    /// The number of seconds of content currently buffered ahead of the playhead.
    public var bufferSeconds: TimeInterval = 0
    /// The loaded portion of the video, from 0 to 100.
    public var loadPercentage: Double = 0
    
    // MARK: - Timeline
    
    /// The total duration of the video, in seconds.
    public var duration: TimeInterval = 0
    /// The current playback position, in seconds.
    public var currentTime: TimeInterval = 0
    /// The playback rate (1.0 is normal speed).
    public var playbackRate: Float = 1.0
    
    // MARK: - Error
    
    public var lastItemError: Error?
    
    // MARK: - Stream
    
    public let stream = AsyncSignal<VideoPlayerMetric>()
    
    // MARK: - Private
    
    private let observer = VideoPlayerMetricsObserver()
    private var preparingStartedAt: Date?
    private var playingStartedAt: Date?
    private var metricsObservationTask: Task<Void, Never>?
    
    // MARK: - Init
    
    /// Creates a new metrics instance and starts the internal event loop.
    ///
    /// Call `bind(_:)` to attach a player; properties update reactively until you call `unbind()`.
    public init() {
        metricsObservationTask = Task { [weak self, observer] in
            for await event in observer.channel.stream {
                guard let self else { return }
                apply(event)
            }
        }
    }
    
    @MainActor
    deinit {
        metricsObservationTask?.cancel()
    }
}

// MARK: - Public Interface

extension VideoPlayerMetrics {
    
    /// Attaches the metrics to the specified player.
    ///
    /// All properties update from this player until you call `unbind()`. Call `unbind()` when releasing the player (for
    /// example, when reusing a cell).
    /// - Parameter player: The player to observe (for example, an `AVPlayer` or `AVQueuePlayer` instance).
    public func bind(_ player: AVPlayer) {
        observer.bind(to: player)
    }
    
    /// Stops observing the current player and clears all subscriptions.
    ///
    /// Call this when releasing the player (for example, when reusing a feed cell).
    public func unbind() {
        observer.unbindAll()
    }
}

// MARK: - Private

extension VideoPlayerMetrics {

    private func apply(_ event: VideoPlayerMetric) {
        switch event {
        case let .timeline(event):
            applyTimeline(event)
        case let .itemLifecycle(event):
            applyItemLifecycle(event)
        case let .buffer(event):
            applyBuffer(event)
        }
        stream.send(event)
    }
    
    private func applyTimeline(_ event: VideoPlayerTimelineEvent) {
        switch event {
        case let .currentTimeUpdated(seconds):
            applyChangedCurrentTime(seconds)
        case let .durationUpdated(seconds):
            duration = seconds
        case let .timeControlStatusChanged(status):
            applyChangedTimeControlStatus(status)
        case let .rateUpdated(rate):
            playbackRate = rate
        case .stalled:
            playbackState = .stalled
        case .ended:
            playbackState = .ended
        case .failedToPlayToEnd:
            playbackState = .failedToPlayToEnd
        }
    }
    
    private func applyChangedCurrentTime(_ seconds: TimeInterval) {
        currentTime = seconds
        if seconds > 0, let start = playingStartedAt {
            timeToFirstFrame = Date().timeIntervalSince(start)
            playingStartedAt = nil
        }
    }
    
    private func applyChangedTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .paused:
            playbackState = .paused
        case .playing:
            playbackState = .playing
        case .waitingToPlayAtSpecifiedRate:
            playbackState = .waitingToPlay
        @unknown default:
            break
        }
        if status == .playing, playingStartedAt == nil, timeToFirstFrame == nil {
            playingStartedAt = Date()
        }
    }

    private func applyItemLifecycle(_ event: VideoPlayerItemLifecycleEvent) {
        switch event {
        case let .statusChanged(status, error):
            parseItemStatus(status, error: error)
        case let .waitingReasonChanged(reason):
            waitingToPlayReason = reason
        case let .itemChanged(item):
            parseItem(item)
        }
    }

    private func applyBuffer(_ event: VideoPlayerBufferEvent) {
        switch event {
        case .bufferEmpty:
            bufferState = .empty
        case .bufferFull:
            bufferState = .full
        case .likelyToKeepUp:
            bufferState = .likelyToKeepUp
        case let .bufferUpdated(secondsInBuffer: seconds, percentage: percentage):
            if bufferState == .empty { bufferState = .buffering }
            bufferSeconds = seconds
            loadPercentage = percentage
        }
    }
    
    private func parseItem(_ item: AVPlayerItem?) {
        itemState = .idle
        timeToReady = nil
        bufferState = .empty
        bufferSeconds = .zero
        loadPercentage = .zero
        timeToFirstFrame = nil
        duration = .zero
        currentTime = .zero
        playbackRate = .zero
        preparingStartedAt = nil
        playingStartedAt = nil
        lastItemError = nil
        waitingToPlayReason = nil
        
        if let item {
            parseItemStatus(item.status, error: item.error)
            let duration = CMTimeGetSeconds(item.duration)
            if duration.isFinite {
                self.duration = duration
            }
        }
    }
    
    private func parseItemStatus(_ status: AVPlayerItem.Status, error: Error?) {
        switch status {
        case .unknown:
            itemState = .preparing
            preparingStartedAt = Date()
        case .readyToPlay:
            itemState = .readyToPlay
            if let preparingStartedAt {
                timeToReady = Date().timeIntervalSince(preparingStartedAt)
            }
            preparingStartedAt = nil
        case .failed:
            itemState = .failed
            preparingStartedAt = nil
            lastItemError = error
        @unknown default:
            break
        }
    }
}
#endif
