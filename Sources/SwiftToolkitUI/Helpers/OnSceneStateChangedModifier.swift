//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2025 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import UIKit

/// A lifecycle event emitted by `onSceneStateChanged`.
public enum SceneState {
    case sceneWillEnterForeground
    case sceneDidEnterBackground
    case sceneDidActivate
    case sceneWillDeactivate
    case sceneWillConnect
    case sceneDidDisconnect
}

struct OnSceneStateChangedModifier: ViewModifier {
    let perform: (SceneState) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(
                for: UIScene.willEnterForegroundNotification
            )) { _ in
                perform(.sceneWillEnterForeground)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIScene.willDeactivateNotification
            )) { _ in
                perform(.sceneWillDeactivate)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIScene.didActivateNotification
            )) { _ in
                perform(.sceneDidActivate)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIScene.didEnterBackgroundNotification
            )) { _ in
                perform(.sceneDidEnterBackground)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIScene.willConnectNotification
            )) { _ in
                perform(.sceneWillConnect)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIScene.didDisconnectNotification
            )) { _ in
                perform(.sceneDidDisconnect)
            }
    }
}

extension View {
    /// Observes `UIScene` lifecycle notifications and reports them as `SceneState` events.
    public func onSceneStateChanged(perform: @escaping (SceneState) -> Void) -> some View {
        modifier(OnSceneStateChangedModifier(perform: perform))
    }
}
#endif
