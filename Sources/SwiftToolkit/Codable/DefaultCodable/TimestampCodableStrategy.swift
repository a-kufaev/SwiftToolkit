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

import Foundation

/// Decodes second-based `TimeInterval` values as a `Date`.
///
/// Use with `@DateValueCodable<TimestampCodableStrategy>` to decode Unix timestamps into `Date`s. Encoding the `Date`
/// will emit the original `TimeInterval` value.
///
/// For example, decoding JSON data with a Unix timestamp of `978307200.0` produces a valid `Date` representing January
/// 1, 2001.
public struct TimestampCodableStrategy: DateValueCodableStrategy {
    public static func decode(_ value: TimeInterval) throws -> Date {
        Date(timeIntervalSince1970: value)
    }

    public static func encode(_ date: Date) -> TimeInterval {
        date.timeIntervalSince1970
    }
}
