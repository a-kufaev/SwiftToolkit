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

#if canImport(UIKit)
import SwiftUI

/// A SwiftUI wrapper around `UIVisualEffectView` for blur and vibrancy effects.
public struct VisualEffectView: UIViewRepresentable {

    let effect: UIVisualEffect

    public init(effect: UIVisualEffect) {
        self.effect = effect
    }

    public init(blurEffectWithStyle style: UIBlurEffect.Style) {
        effect = UIBlurEffect(style: style)
    }

    public func makeUIView(context _: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context _: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}
#endif
