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

@Suite("LossyDecodingReporter")
struct LossyDecodingReporterTests {

    private struct Model: Decodable {
        @LossyCodableArray var ids: [Int]
        @LossyOptionalCodable var website: URL?
    }

    private final class CollectingReporter: LossyDecodingReporter, @unchecked Sendable {
        private(set) var errors: [Error] = []
        func lossyDecodingDidDrop(_ error: Error, codingPath _: [CodingKey]) {
            errors.append(error)
        }
    }

    private func decode(_ json: String, reporter: CollectingReporter) throws -> Model {
        let decoder = JSONDecoder()
        decoder.userInfo[.lossyDecodingReporter] = reporter
        return try decoder.decode(Model.self, from: Data(json.utf8))
    }

    @Test("reports each element a lossy array drops")
    func reportsDroppedArrayElement() throws {
        let reporter = CollectingReporter()
        let model = try decode(#"{"ids":[1,"x",3]}"#, reporter: reporter)
        #expect(model.ids == [1, 3])
        #expect(reporter.errors.count == 1)
    }

    @Test("reports a present-but-invalid value that falls back to nil")
    func reportsDefaultFallback() throws {
        let reporter = CollectingReporter()
        let model = try decode(#"{"ids":[],"website":123}"#, reporter: reporter)
        #expect(model.website == nil)
        #expect(reporter.errors.count == 1)
    }

    @Test("stays silent for a legitimately absent key")
    func ignoresAbsentKey() throws {
        let reporter = CollectingReporter()
        _ = try decode(#"{"ids":[]}"#, reporter: reporter)
        #expect(reporter.errors.isEmpty)
    }

    @Test("decoding without a reporter keeps the lossy behaviour")
    func decodesWithoutReporter() throws {
        let model = try JSONDecoder().decode(Model.self, from: Data(#"{"ids":[1,"x",3]}"#.utf8))
        #expect(model.ids == [1, 3])
    }
}
