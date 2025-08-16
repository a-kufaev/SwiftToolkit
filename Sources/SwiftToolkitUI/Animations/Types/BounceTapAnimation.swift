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

@MainActor
struct BounceTapAnimation: TapViewAnimation {
    var modifier: ((Bool) -> BounceTapAnimationViewModifier) = {
        BounceTapAnimationViewModifier(isPressed: $0)
    }

    var startAnimation: Animation = .easeInOut(duration: 0.15)
    var startAnimationDuration: TimeInterval = 0.15
    var endAnimation: Animation = .easeInOut(duration: 0.2)
}

struct BounceTapAnimationViewModifier: ViewModifier {
    private let isPressed: Bool

    init(isPressed: Bool) {
        self.isPressed = isPressed
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1)
    }
}
