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

extension Color {
    /// A near-transparent color that still participates in hit-testing.
    ///
    /// `Color.clear` is not hit-testable, so use this when a transparent background must still
    /// receive touches.
    public static var hitTestableClear: Color {
        Color.black.opacity(0.00001)
    }
}
