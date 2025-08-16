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

import SwiftUI

/// The set of built-in press animations available via `onTapGesture(animation:tapHandler:)`.
public enum TapAnimateTypes {
    /// Scales the view down slightly while pressed.
    case bounce
    /// Fades the view while pressed.
    case fade
    /// Fills the view's background with a color while pressed.
    case fill(Color)

    @MainActor
    public static let fill = fill(.clear)
}

// MARK: - View Extension

extension View {
    /// Adds a tap gesture with a built-in press animation.
    ///
    /// - Parameters:
    ///   - animation: The press animation to apply.
    ///   - longPressHandler: Optional callback invoked with the pressing state.
    ///   - tapHandler: Invoked when the tap is recognized.
    public func onTapGesture(
        animation: TapAnimateTypes,
        longPressHandler: ((Bool) -> Void)? = nil,
        tapHandler: @escaping () -> Void
    ) -> some View {
        switch animation {
        case .bounce:
            let animation = BounceTapAnimation()
            return modifier(
                TapAnimationModifier(
                    animation: animation,
                    longPressHandler: longPressHandler,
                    tapHandler: tapHandler
                )
            ).eraseToAnyView()

        case .fade:
            let animation = FadeTapAnimation()
            return modifier(
                TapAnimationModifier(
                    animation: animation,
                    longPressHandler: longPressHandler,
                    tapHandler: tapHandler
                )
            ).eraseToAnyView()

        case let .fill(color):
            let animation = FillTapAnimation(color: color)
            return modifier(
                TapAnimationModifier(
                    animation: animation,
                    longPressHandler: longPressHandler,
                    tapHandler: tapHandler
                )
            ).eraseToAnyView()
        }
    }
}

extension View {
    public func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
