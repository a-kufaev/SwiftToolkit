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

/// A `GeometryEffect` that shifts a view horizontally along a sine wave to produce a shake.
///
/// Drive it with an animation on `isShaking` — typically used to signal an invalid input.
public struct ShakeModifier: GeometryEffect {
    public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // For animation. Changes from 0 to 1.
    private var progress: CGFloat

    // How far the view will be shifted.
    private let xOffset: CGFloat

    public init(isShaking: Bool, xOffset: CGFloat = 8) {
        progress = isShaking ? 1 : .zero
        self.xOffset = xOffset
    }

    public func effectValue(size _: CGSize) -> ProjectionTransform {
        // Move along a sine wave, where 2 * .pi is one full period.
        // As progress goes 0 -> 1 along X, Y follows 0 -> 1 -> -1 -> 0:
        // shift one way, then the other, then back to the original position.
        let translationX: CGFloat = xOffset * sin(progress * 2 * .pi)
        let transform = CGAffineTransform(translationX: translationX, y: .zero)
        return ProjectionTransform(transform)
    }
}

extension View {
    /// Applies a horizontal shake effect driven by `isShaking`.
    public func shake(isShaking: Bool, xOffset: CGFloat = 8) -> some View {
        modifier(ShakeModifier(isShaking: isShaking, xOffset: xOffset))
    }
}
