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
import UIKit

extension Color {

    /// Creates a `Color` from a hex string.
    /// - Parameter hex: Hex string (supports 3, 6, or 8 character formats).
    /// - Examples: `"FF0000"`, `"F00"`, `"80FF0000"`.
    public init(hex: String) {
        self.init(UIColor(hex: hex))
    }
}

extension UIColor {

    /// Creates a dynamic `UIColor` from light and dark hex strings.
    public convenience init(light: String, dark: String) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                .init(hex: dark)
            case .light, .unspecified:
                .init(hex: light)
            @unknown default:
                .init(hex: light)
            }
        }
    }

    /// Creates a `UIColor` from a hex string.
    /// - Parameter hex: Hex string (supports 3, 6, or 8 character formats).
    /// - Examples: `"FF0000"`, `"F00"`, `"80FF0000"`.
    public convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let red, green, blue, alpha: UInt64

        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            assertionFailure("Unexpected color's hex")
            (alpha, red, green, blue) = (255, 255, 255, 255)
        }

        self.init(
            displayP3Red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            alpha: Double(alpha) / 255
        )
    }
}
#endif
