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

/// A protocol for providing a custom strategy for encoding and decoding dates.
///
/// `DateValueCodableStrategy` provides a generic strategy type that the `DateValueCodable` property wrapper can use to
/// inject custom strategies for encoding and decoding date values.
public protocol DateValueCodableStrategy {
    associatedtype RawValue: Sendable

    static func decode(_ value: RawValue) throws -> Date
    static func encode(_ date: Date) -> RawValue
}

/// Decodes and encodes dates using a strategy type.
///
/// `@DateValueCodable` decodes dates using a `DateValueCodableStrategy` which provides custom decoding and encoding
/// functionality.
@propertyWrapper
public struct DateValueCodable<Formatter: DateValueCodableStrategy>: Sendable {
    public var wrappedValue: Date

    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }
}

extension DateValueCodable: Decodable where Formatter.RawValue: Decodable {
    public init(from decoder: Decoder) throws {
        let value = try Formatter.RawValue(from: decoder)
        wrappedValue = try Formatter.decode(value)
    }
}

extension DateValueCodable: Encodable where Formatter.RawValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        let value = Formatter.encode(wrappedValue)
        try value.encode(to: encoder)
    }
}

extension DateValueCodable: Equatable {
    public static func == (lhs: DateValueCodable<Formatter>, rhs: DateValueCodable<Formatter>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension DateValueCodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}
