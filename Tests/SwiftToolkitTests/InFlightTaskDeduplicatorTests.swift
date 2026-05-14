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

@Suite("InFlightTaskDeduplicator")
struct InFlightTaskDeduplicatorTests {

    @Test("concurrent calls with the same key run the operation once")
    func dedupesByKey() async throws {
        let dedup = InFlightTaskDeduplicator<Int>()
        let counter = CallCounter()

        async let first = dedup.run(key: "shared") {
            await counter.bump()
            try? await Task.sleep(for: .milliseconds(50))
            return 1
        }
        async let second = dedup.run(key: "shared") {
            await counter.bump()
            try? await Task.sleep(for: .milliseconds(50))
            return 1
        }

        let results = try await [first, second]

        #expect(results == [1, 1])
        await #expect(counter.count == 1)
    }

    @Test("different keys run independently")
    func differentKeysRunIndependently() async throws {
        let dedup = InFlightTaskDeduplicator<Int>()
        let counter = CallCounter()

        async let first = dedup.run(key: "a") {
            await counter.bump()
            return 1
        }
        async let second = dedup.run(key: "b") {
            await counter.bump()
            return 2
        }

        _ = try await (first, second)

        await #expect(counter.count == 2)
    }
}

private actor CallCounter {
    private(set) var count = 0
    func bump() { count += 1 }
}
