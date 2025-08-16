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

struct FillTapAnimation: TapViewAnimation {
    init(color: Color) {
        modifier = { FillTapAnimationViewModifier(isPressed: $0, color: color) }
    }

    var modifier: (Bool) -> FillTapAnimationViewModifier

    var startAnimation: Animation = .linear(duration: 0.1)
    var startAnimationDuration: TimeInterval = 0.1
    var endAnimation: Animation = .easeOut(duration: 0.4)
}

struct FillTapAnimationViewModifier: ViewModifier {

    var color: Color
    private let isPressed: Bool

    init(isPressed: Bool, color: Color) {
        self.isPressed = isPressed
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .background(
                isPressed ? color : .hitTestableClear
            )
    }
}
