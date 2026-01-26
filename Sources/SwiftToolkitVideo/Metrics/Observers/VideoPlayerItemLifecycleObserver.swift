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

/// Observes AVPlayer (reasonForWaitingToPlay) and AVPlayerItem (status) for lifecycle events.
@MainActor
final class VideoPlayerItemLifecycleObserver {
    
    /// Stream of item lifecycle events (status, waiting reason, item change).
    let channel = AsyncSignal<VideoPlayerItemLifecycleEvent>()
    
    private var playerObservations: [NSKeyValueObservation] = []
    private var itemObservations: [NSKeyValueObservation] = []
    
    deinit {
        playerObservations.forEach { $0.invalidate() }
        itemObservations.forEach { $0.invalidate() }
    }
}

// MARK: - Interface

extension VideoPlayerItemLifecycleObserver {
    
    /// Observes the player's reasonForWaitingToPlay.
    func bind(to player: AVPlayer) {
        observePlayer(player)
    }
    
    /// Observes the item's status.
    func bind(to item: AVPlayerItem) {
        observeItemKVO(item)
    }
    
    /// Removes both player and item observations.
    func unbindPlayer() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations.removeAll()
        playerObservations.forEach { $0.invalidate() }
        playerObservations.removeAll()
    }
    
    /// Removes only item observations (player observations remain).
    func unbindItem() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations.removeAll()
    }
}

// MARK: - Player observing

extension VideoPlayerItemLifecycleObserver {
    
    private func observePlayer(_ player: AVPlayer) {
        playerObservations.append(player.observe(\.reasonForWaitingToPlay, options: [
            .new,
            .initial
        ]) { [weak self] observedItem, _ in
            guard let self else { return }
            channel.send(.waitingReasonChanged(observedItem.reasonForWaitingToPlay))
        })
    }
}

// MARK: - Item KVO

extension VideoPlayerItemLifecycleObserver {

    private func observeItemKVO(_ item: AVPlayerItem) {
        itemObservations.append(item.observe(\.status, options: [.new, .initial]) { [weak self] observedItem, _ in
            guard let self else { return }
            channel.send(.statusChanged(observedItem.status, error: observedItem.error))
        })
    }
}
#endif
