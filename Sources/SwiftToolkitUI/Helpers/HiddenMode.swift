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

/// Defines different ways to hide a view while preserving or releasing its space.
public enum HiddenMode {
    /// Hides the view using the `hidden()` modifier without releasing occupied space.
    /// Triggers `onFirstAppear` and `onAppear` when the view becomes visible.
    case hidden
    /// Hides the view using opacity without releasing occupied space.
    /// Does not trigger `onAppear` when the view becomes visible.
    case opacity
    /// Completely removes the view from the hierarchy, releasing occupied space.
    case removed
}

extension View {
    /// Hides or shows a view based on a boolean value with three different hiding modes.
    ///
    /// - Parameters:
    ///   - hidden: Flag determining whether to hide the view.
    ///   - mode: Mode defining the hiding behavior.
    @ViewBuilder
    public func hidden(_ hidden: Bool, mode: HiddenMode) -> some View {
        switch mode {
        case .hidden:
            if hidden {
                self.hidden()
            } else {
                self
            }
        case .opacity:
            opacity(hidden ? 0 : 1)
        case .removed:
            if !hidden {
                self
            }
        }
    }
}
