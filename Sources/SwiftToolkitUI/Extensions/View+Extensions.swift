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

extension View {

    @ViewBuilder
    public func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }

    /// Applies a transform to a view only when the condition is met.
    @ViewBuilder
    public func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a transform to a view only when the optional value is non-nil.
    @ViewBuilder
    public func ifLet<Value>(
        _ optionalValue: Value?,
        then content: (Self, Value) -> some View
    ) -> some View {
        if let value = optionalValue {
            content(self, value)
        } else {
            self
        }
    }

    /// Performs an action the first time the view appears (and not on subsequent appearances).
    public func onFirstAppear(perform: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(perform: perform))
    }

    /// Sets a square frame using a single dimension.
    @inlinable
    public func frame(_ size: CGFloat?, alignment: Alignment = .center) -> some View {
        frame(width: size, height: size, alignment: alignment)
    }

    /// Expands the view to fill the available space.
    @inlinable
    public func fillFrame(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

struct OnFirstAppearModifier: ViewModifier {

    @State
    private var firstTime = true

    let perform: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard firstTime else { return }
                firstTime = false
                perform()
            }
    }
}

extension View {

    /// Reads the view's size, invoking `onChange` whenever it changes.
    public func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newValue in
            onChange(newValue)
        }
    }

    /// Binds the view's size into the provided binding.
    @ViewBuilder
    public func bindSize(_ size: Binding<CGSize>) -> some View {
        onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newValue in
            size.wrappedValue = newValue
        }
    }
}
