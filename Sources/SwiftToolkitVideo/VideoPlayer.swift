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
import UIKit

/// SwiftUI wrapper for a dumb, layer-only video player (AVPlayerLayer).
///
/// Use for any place where you want video without system controls.
/// For system UI (controls, PiP, Now Playing), use `VideoPlayerWithControls`.
public struct VideoPlayer: UIViewRepresentable {

    public typealias UIViewType = AVPlayerView

    private let player: AVPlayer?
    private var videoGravity: AVLayerVideoGravity?

    public init(player: AVPlayer?) {
        self.player = player
    }

    public func makeUIView(context _: Context) -> UIViewType {
        let view = UIViewType()
        view.player = player
        return view
    }

    public func updateUIView(_ uiView: UIViewType, context _: Context) {
        if uiView.player !== player {
            uiView.player = player
        }
        if let videoGravity, uiView.videoGravity != videoGravity {
            uiView.videoGravity = videoGravity
        }
    }
}

// MARK: - Builder-style API

extension VideoPlayer: Buildable {
    
    /// Sets how the video is scaled within the view (e.g. `.resizeAspectFill` for full-bleed).
    public func videoGravity(_ videoGravity: AVLayerVideoGravity) -> Self {
        map { $0.videoGravity = videoGravity }
    }
}
#endif
