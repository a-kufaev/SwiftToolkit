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

/// Decodes millisecond `TimeInterval` values as a `Date`.
///
/// Use with `@DateValueCodable<MillisecondsTimestampCodableStrategy>` to decode millisecond Unix timestamps into
/// `Date`s. Encoding the `Date` will encode the value into the original millisecond `TimeInterval` value.
///
/// For example, decoding JSON data with a millisecond timestamp of `978307200000` produces a valid `Date` representing
/// January 1, 2001.
public struct MillisecondsTimestampCodableStrategy: DateValueCodableStrategy {
    public static func decode(_ value: TimeInterval) throws -> Date {
        Date(timeIntervalSince1970: value / 1000)
    }

    public static func encode(_ date: Date) -> TimeInterval {
        date.timeIntervalSince1970 * 1000
    }
}
