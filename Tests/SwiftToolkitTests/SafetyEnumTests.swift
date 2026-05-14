//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2026 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
@testable import SwiftToolkit
import Testing

@Suite("SafetyEnum")
struct SafetyEnumTests {

    private enum Fruit: String, CaseIterable, SafetyEnum {
        case apple
        case banana
        case failure
    }

    @Test("a known raw value decodes to its case")
    func knownValueDecodes() throws {
        let value = try JSONDecoder().decode(Fruit.self, from: Data(#""apple""#.utf8))
        #expect(value == .apple)
    }

    @Test("an unknown raw value falls back to the failure case")
    func unknownValueFallsBack() throws {
        let value = try JSONDecoder().decode(Fruit.self, from: Data(#""durian""#.utf8))
        #expect(value == .failure)
    }
}
