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

import Combine
import SwiftUI

@MainActor
protocol TapViewAnimation {
    associatedtype Modifier: ViewModifier

    var modifier: (Bool) -> Modifier { get }
    var startAnimation: Animation { get }
    var startAnimationDuration: TimeInterval { get }
    var endAnimation: Animation { get }
}

struct TapAnimationModifier<T: TapViewAnimation>: ViewModifier {

    @State
    private var isPressed = false
    @State
    private var isTapped = false

    private let animationCompletionSubject = PassthroughSubject<Void, Never>()
    @State
    private var animationCompleted = false
    @State
    private var animationCompletionSubscription: AnyCancellable?

    private let animation: T
    private let tapHandler: () -> Void
    private let longPressHandler: ((Bool) -> Void)?

    init(
        animation: T,
        longPressHandler: ((Bool) -> Void)? = nil,
        tapHandler: @escaping () -> Void
    ) {
        self.animation = animation
        self.tapHandler = tapHandler
        self.longPressHandler = longPressHandler
    }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .modifier(animation.modifier(isPressed))
            .onTapGesture {
                isTapped = true
                if animationCompleted {
                    endAnimation()
                } else {
                    animationCompletionSubscription = animationCompletionSubject.sink {
                        endAnimation()
                    }
                }

                tapHandler()
            }
            .onLongPressGesture(
                minimumDuration: .infinity,
                maximumDistance: .infinity,
                pressing: { pressing in
                    if pressing {
                        withAnimation(animation.startAnimation) {
                            isPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + animation.startAnimationDuration) {
                            animationCompleted = true
                            animationCompletionSubject.send()
                        }
                    } else if !isTapped {
                        endAnimation()
                    }
                    longPressHandler?(pressing)
                },
                perform: {}
            )
    }

    private func endAnimation() {
        animationCompleted = false
        isTapped = false
        animationCompletionSubscription?.cancel()
        animationCompletionSubscription = nil

        withAnimation(animation.endAnimation) {
            isPressed = false
        }
    }
}
