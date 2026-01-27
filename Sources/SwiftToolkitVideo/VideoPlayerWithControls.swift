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
import SwiftToolkitUI
import SwiftUI

/// SwiftUI wrapper around `AVPlayerViewController` (system controls, PiP, Now Playing).
///
/// Use when you need the full system player UI/behavior. For layer-only playback (feeds, loops),
/// use `VideoPlayer` from VideoPlayerLayer.swift instead.
public struct VideoPlayerWithControls: UIViewControllerRepresentable {

    fileprivate struct Configuration: Equatable {
        var showsPlaybackControls: Bool?
        var videoGravity: AVLayerVideoGravity?
        var allowsPictureInPicturePlayback: Bool?
        var updatesNowPlayingInfoCenter: Bool?
        /// Enables/disables system frame-level analysis features when supported by the OS/device.
        var allowsVideoFrameAnalysis: Bool?
    }

    private let viewController: AVPlayerViewController
    private var configuration = Configuration()
    
    public init(player: AVPlayer) {
        viewController = AVPlayerViewController()
        viewController.player = player
    }
    
    public init(viewController: AVPlayerViewController) {
        self.viewController = viewController
    }

    public func makeUIViewController(context _: Context) -> AVPlayerViewController {
        // Transparent background to keep all visual styling under SwiftUI control.
        viewController.view.backgroundColor = .clear
        configuration.apply(to: viewController)
        return viewController
    }

    public func updateUIViewController(_ viewController: AVPlayerViewController, context _: Context) {
        configuration.apply(to: viewController)
    }
}

// MARK: - Builder-style API

extension VideoPlayerWithControls: Buildable {

    /// Shows/hides system playback controls.
    ///
    /// Useful for feed-style playback where you provide custom controls (or none).
    public func showsPlaybackControls(_ shows: Bool) -> Self {
        map { $0.configuration.showsPlaybackControls = shows }
    }

    /// Sets how the video is scaled within the view (e.g. `.resizeAspectFill` for full-bleed).
    public func videoGravity(_ videoGravity: AVLayerVideoGravity) -> Self {
        map { $0.configuration.videoGravity = videoGravity }
    }

    /// Enables/disables Picture-in-Picture.
    public func allowsPictureInPicturePlayback(_ allows: Bool) -> Self {
        map { $0.configuration.allowsPictureInPicturePlayback = allows }
    }

    /// Controls whether this player updates system “Now Playing” metadata.
    ///
    /// When enabled, the system may show playback info and controls in Control Center / Lock Screen
    /// for this player. Typically disabled for autoplay feeds to avoid taking over system media UI.
    public func updatesNowPlayingInfoCenter(_ updates: Bool) -> Self {
        map { $0.configuration.updatesNowPlayingInfoCenter = updates }
    }

    /// Controls whether the system may perform video frame analysis (when available).
    ///
    /// This is related to OS-level features that inspect frames for visual understanding. In a feed,
    /// you may want to disable it to reduce extra work and keep playback lightweight.
    public func allowsVideoFrameAnalysis(_ allows: Bool) -> Self {
        map { $0.configuration.allowsVideoFrameAnalysis = allows }
    }
}

// MARK: - Apply

extension VideoPlayerWithControls.Configuration {
    @MainActor
    fileprivate func apply(to viewController: AVPlayerViewController) {
        if let showsPlaybackControls, viewController.showsPlaybackControls != showsPlaybackControls {
            viewController.showsPlaybackControls = showsPlaybackControls
        }
        if let videoGravity, viewController.videoGravity != videoGravity {
            viewController.videoGravity = videoGravity
        }
        if let allowsPictureInPicturePlayback,
           viewController.allowsPictureInPicturePlayback != allowsPictureInPicturePlayback {
            viewController.allowsPictureInPicturePlayback = allowsPictureInPicturePlayback
        }
        if let updatesNowPlayingInfoCenter,
           viewController.updatesNowPlayingInfoCenter != updatesNowPlayingInfoCenter {
            viewController.updatesNowPlayingInfoCenter = updatesNowPlayingInfoCenter
        }
        if let allowsVideoFrameAnalysis,
           viewController.allowsVideoFrameAnalysis != allowsVideoFrameAnalysis {
            viewController.allowsVideoFrameAnalysis = allowsVideoFrameAnalysis
        }
    }
}
#endif
