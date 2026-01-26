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
import AVFoundation
import AVKit
import SwiftToolkit

/// Observes a single AVPlayer (and its current item), multiplexes timeline, item lifecycle,
/// buffer, and ABR events into a single AsyncSignal<VideoPlayerMetric> stream.
/// Used internally by VideoPlayerMetrics; bind(to:) / unbindAll() when attaching/detaching the player.
@MainActor
final class VideoPlayerMetricsObserver {
    
    /// Stream of all metrics events from the bound player and item. Consumed by VideoPlayerMetrics.
    let channel = AsyncSignal<VideoPlayerMetric>()
    
    // MARK: - Player state
    
    private var currentItemObservation: NSKeyValueObservation?
    
    // MARK: - Observers
    
    private let bufferObserver = VideoPlayerBufferObserver()
    private let timelineObserver = VideoPlayerTimelineObserver()
    private let itemLifecycleObserver = VideoPlayerItemLifecycleObserver()
    
    private var observationTasks: [Task<Void, Never>] = []
    
    // MARK: - Init
    
    init() {
        observationTasks.append(Task { [weak self, bufferObserver] in
            for await event in bufferObserver.channel {
                guard let self else { return }
                channel.send(.buffer(event))
            }
        })
        observationTasks.append(Task { [weak self, timelineObserver] in
            for await event in timelineObserver.channel {
                guard let self else { return }
                channel.send(.timeline(event))
            }
        })
        observationTasks.append(Task { [weak self, itemLifecycleObserver] in
            for await event in itemLifecycleObserver.channel {
                guard let self else { return }
                channel.send(.itemLifecycle(event))
            }
        })
    }
    
    deinit {
        observationTasks.forEach { $0.cancel() }
        currentItemObservation?.invalidate()
    }
}

// MARK: - Interface

extension VideoPlayerMetricsObserver {
    
    /// Attaches to the player and its current item; starts forwarding events to `channel`. Call before reading metrics.
    func bind(to player: AVPlayer) {
        timelineObserver.unbindPlayer()
        itemLifecycleObserver.unbindPlayer()
        invalidatePlayerObservations()
        
        observeCurrentItem(player)
        timelineObserver.bind(to: player)
        itemLifecycleObserver.bind(to: player)
        
        if let item = player.currentItem {
            bind(to: item)
        }
    }
    
    /// Attaches to a specific item (e.g. when player.currentItem changes). Unbinds any previously bound item.
    func bind(to item: AVPlayerItem) {
        unbindItem()
        itemLifecycleObserver.bind(to: item)
        bufferObserver.bind(to: item)
        timelineObserver.bind(to: item)
    }
    
    /// Stops observing the player and item; no further events are sent. Call when detaching (e.g. cell reuse).
    func unbindAll() {
        timelineObserver.unbindPlayer()
        invalidatePlayerObservations()
        itemLifecycleObserver.unbindPlayer()
        unbindItem()
    }
}

// MARK: - Player observations

extension VideoPlayerMetricsObserver {
    
    private func observeCurrentItem(_ player: AVPlayer) {
        currentItemObservation = player.observe(
            \.currentItem,
            options: [.new, .initial]
        ) { [weak self] observedPlayer, _ in
            guard let self else { return }
            channel.send(.itemLifecycle(.itemChanged(observedPlayer.currentItem)))
            MainActor.assumeIsolated {
                if let item = observedPlayer.currentItem {
                    bind(to: item)
                } else {
                    unbindItem()
                }
            }
        }
    }
    
    private func invalidatePlayerObservations() {
        currentItemObservation?.invalidate()
        currentItemObservation = nil
    }
}

// MARK: - Unbind item

extension VideoPlayerMetricsObserver {

    private func unbindItem() {
        bufferObserver.unbind()
        itemLifecycleObserver.unbindItem()
        timelineObserver.unbindItem()
    }
}
#endif
