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

@Suite("DefaultCodable")
struct DefaultCodableTests {

    private struct Model: Decodable {
        @DefaultFalseCodable var flag: Bool
        @LossyCodableArray var ids: [Int]
        @DateValueCodable<TimestampCodableStrategy> var createdAt: Date
    }

    @Test("missing bool defaults to false")
    func missingBoolDefaultsToFalse() throws {
        let json = Data(#"{"ids":[1,2],"createdAt":978307200}"#.utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.flag == false)
    }

    @Test("lossy array drops invalid elements")
    func lossyArrayDropsInvalidElements() throws {
        let json = Data(#"{"flag":true,"ids":[1,"x",3],"createdAt":0}"#.utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.ids == [1, 3])
    }

    @Test("timestamp strategy decodes seconds into a Date")
    func timestampStrategyDecodesDate() throws {
        let json = Data(#"{"flag":true,"ids":[],"createdAt":978307200}"#.utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.createdAt == Date(timeIntervalSince1970: 978_307_200))
    }

    @Test("bool strategy coerces an integer into a Bool")
    func boolStrategyCoercesInteger() throws {
        let json = Data(#"{"flag":1,"ids":[],"createdAt":0}"#.utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.flag == true)
    }
}
