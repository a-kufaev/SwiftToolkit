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

/// Observes AVPlayerItem buffer state: empty/full/likelyToKeepUp and loadedTimeRanges
/// to emit buffer seconds and load percentage.
@MainActor
final class VideoPlayerBufferObserver {
    
    /// Stream of buffer events (empty, full, likelyToKeepUp, bufferUpdated).
    let channel = AsyncSignal<VideoPlayerBufferEvent>()
    
    private var itemObservations: [NSKeyValueObservation] = []
    
    deinit {
        itemObservations.forEach { $0.invalidate() }
    }
}

// MARK: - Interface

extension VideoPlayerBufferObserver {
    
    /// Observes the item's buffer flags and loadedTimeRanges; emits buffer state and progress.
    func bind(to item: AVPlayerItem) {
        observeItemKVO(item)
    }
    
    /// Removes all item observations; no further buffer events are sent.
    func unbind() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations.removeAll()
    }
}

// MARK: - Observers

extension VideoPlayerBufferObserver {
    
    private func observeItemKVO(_ item: AVPlayerItem) {
        itemObservations.append(item.observe(\.isPlaybackBufferEmpty, options: [
            .new,
            .initial
        ]) { [weak self] observedItem, _ in
            guard let self, observedItem.isPlaybackBufferEmpty else { return }
            channel.send(.bufferEmpty)
        })
        
        itemObservations.append(item.observe(\.isPlaybackBufferFull, options: [
            .new,
            .initial
        ]) { [weak self] observedItem, _ in
            guard let self, observedItem.isPlaybackBufferFull else { return }
            channel.send(.bufferFull)
        })
        
        itemObservations.append(item.observe(\.isPlaybackLikelyToKeepUp, options: [
            .new,
            .initial
        ]) { [weak self] observedItem, _ in
            guard let self, observedItem.isPlaybackLikelyToKeepUp else { return }
            channel.send(.likelyToKeepUp)
        })
        
        itemObservations.append(item.observe(\.loadedTimeRanges, options: [
            .new,
            .initial
        ]) { [weak self] observedItem, _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                let seconds = Self.bufferSeconds(for: observedItem)
                let percentage = Self.loadPercentage(for: observedItem)
                channel.send(.bufferUpdated(secondsInBuffer: seconds, percentage: percentage))
            }
        })
    }
}

// MARK: - Buffer helpers

extension VideoPlayerBufferObserver {

    /// Seconds of content buffered ahead of the current time (from loadedTimeRanges).
    private static func bufferSeconds(for item: AVPlayerItem) -> TimeInterval {
        let ranges = item.loadedTimeRanges
        let current = item.currentTime().seconds
        var maxEnd: TimeInterval = current
        for value in ranges {
            let range = value.timeRangeValue
            let end = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration)
            if end > maxEnd { maxEnd = end }
        }
        return max(.zero, maxEnd - current)
    }

    /// Loaded portion of the video (0...100) from loadedTimeRanges and duration.
    private static func loadPercentage(for item: AVPlayerItem) -> Double {
        let duration = CMTimeGetSeconds(item.duration)
        guard duration.isFinite, duration > .zero else { return .zero }
        let loaded = loadedDuration(for: item)
        return min(100, max(.zero, (loaded / duration) * 100))
    }

    /// Total length of loaded time ranges (union of segments) in seconds.
    private static func loadedDuration(for item: AVPlayerItem) -> TimeInterval {
        let ranges = item.loadedTimeRanges
        guard !ranges.isEmpty else { return .zero }
        var union: [(start: TimeInterval, end: TimeInterval)] = []
        for value in ranges {
            let range = value.timeRangeValue
            let start = CMTimeGetSeconds(range.start)
            let end = start + CMTimeGetSeconds(range.duration)
            union.append((start, end))
        }
        union.sort { $0.start < $1.start }
        var total: TimeInterval = .zero
        var lastEnd: TimeInterval = .zero
        for seg in union {
            if seg.end <= lastEnd { continue }
            let start = max(seg.start, lastEnd)
            total += seg.end - start
            lastEnd = seg.end
        }
        return total
    }
}
#endif
