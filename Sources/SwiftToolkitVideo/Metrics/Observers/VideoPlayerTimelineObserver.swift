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

/// Observes AVPlayer and current item for timeline events: timeControlStatus, rate, currentTime,
/// duration, and notifications (ended, stalled, failedToPlayToEnd).
@MainActor
final class VideoPlayerTimelineObserver {
    
    /// Stream of timeline events (time control, duration, position, rate, ended/stalled/failed).
    let channel = AsyncSignal<VideoPlayerTimelineEvent>()
    
    // MARK: - Properties
    
    private weak var boundPlayer: AVPlayer?
    
    private var timeControlObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var itemObservations: [NSKeyValueObservation] = []
    private var notificationTasks: [Task<Void, Never>] = []
    
    deinit {
        timeControlObservation?.invalidate()
        rateObservation?.invalidate()
        itemObservations.forEach { $0.invalidate() }
        notificationTasks.forEach { $0.cancel() }
    }
}

// MARK: - Interface

extension VideoPlayerTimelineObserver {
    
    /// Observes the player's timeControlStatus, rate, and adds a periodic time observer.
    func bind(to player: AVPlayer) {
        boundPlayer = player
        observePlayer(player)
    }
    
    /// Observes the item's duration and playback notifications (ended, stalled, failedToPlayToEnd).
    func bind(to item: AVPlayerItem) {
        observeItemKVO(item)
        observeItemNotifications(item)
    }
    
    /// Removes player observations and the periodic time observer.
    func unbindPlayer() {
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        
        rateObservation?.invalidate()
        rateObservation = nil
        
        if let player = boundPlayer, let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
        
        boundPlayer = nil
    }
    
    /// Removes item KVO and notification tasks.
    func unbindItem() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations.removeAll()
        notificationTasks.forEach { $0.cancel() }
        notificationTasks.removeAll()
    }
}

// MARK: - Player observing

extension VideoPlayerTimelineObserver {
    
    private func observePlayer(_ player: AVPlayer) {
        timeControlObservation = player.observe(
            \.timeControlStatus,
            options: [.new, .initial]
        ) { [weak self] observedPlayer, change in
            guard let self else { return }
            let status = change.newValue ?? observedPlayer.timeControlStatus
            channel.send(.timeControlStatusChanged(status))
        }
        
        rateObservation = player.observe(\.rate, options: [.new, .initial]) { [weak self] observedPlayer, change in
            guard let self else { return }
            let rate = change.newValue ?? observedPlayer.rate
            channel.send(.rateUpdated(rate))
        }
        
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: .periodicTimeInterval,
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            channel.send(.currentTimeUpdated(seconds))
        }
    }
}

// MARK: - Item KVO

extension VideoPlayerTimelineObserver {
    
    private func observeItemKVO(_ item: AVPlayerItem) {
        itemObservations.append(item.observe(\.duration, options: [.new, .initial]) { [weak self] observedItem, _ in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(observedItem.duration)
            guard seconds.isFinite, seconds > .zero else { return }
            channel.send(.durationUpdated(seconds))
        })
    }
}

// MARK: - Item notifications

extension VideoPlayerTimelineObserver {

    private func observeItemNotifications(_ item: AVPlayerItem) {
        let center = NotificationCenter.default

        notificationTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: .AVPlayerItemDidPlayToEndTime, object: item) {
                guard let self else { return }
                channel.send(.ended)
            }
        })
        notificationTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: .AVPlayerItemPlaybackStalled, object: item) {
                guard let self else { return }
                channel.send(.stalled)
            }
        })
        notificationTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: .AVPlayerItemFailedToPlayToEndTime, object: item) {
                guard let self else { return }
                channel.send(.failedToPlayToEnd)
            }
        })
    }
}

// MARK: - Constants

extension CMTime {
    fileprivate static let periodicTimeInterval = CMTime(value: 1, timescale: 4)
}
#endif
