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

@MainActor
@Suite("AsyncDataStore")
struct AsyncDataStoreTests {

    private final class TestStore: AsyncDataStore<Int> {
        var result: Result<Int, any Error> = .success(1)
        private(set) var fetchCount = 0

        override func fetch(force _: Bool) async throws -> Int {
            fetchCount += 1
            return try result.get()
        }
    }

    private struct SampleError: Error {}

    @Test("successful load stores content and marks loaded")
    func successfulLoad() async throws {
        let store = TestStore()
        let value = try await store.load()

        #expect(value == 1)
        #expect(store.content == 1)
        #expect(store.phase == .loaded)
        #expect(store.lastError == nil)
    }

    @Test("a failed first load surfaces the error phase")
    func failedLoad() async {
        let store = TestStore()
        store.result = .failure(SampleError())

        await #expect(throws: SampleError.self) {
            try await store.load()
        }
        #expect(store.content == nil)
        #expect(store.phase == .error)
        #expect(store.lastError != nil)
    }

    @Test("reset clears content and returns to idle")
    func resetClearsState() async throws {
        let store = TestStore()
        try await store.load()

        store.reset()

        #expect(store.content == nil)
        #expect(store.phase == .idle)
    }

    @Test("set marks content as loaded without fetching")
    func setMarksLoaded() {
        let store = TestStore()
        store.set(99)

        #expect(store.content == 99)
        #expect(store.phase == .loaded)
        #expect(store.fetchCount == 0)
    }
}
