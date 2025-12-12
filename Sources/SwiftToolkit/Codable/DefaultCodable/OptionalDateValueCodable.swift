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

/// Decodes and encodes optional dates using a strategy type.
///
/// Use `@OptionalDateValueCodable` when a date can be missing and must be converted from/into a specific raw value
/// format defined by the `DateValueCodableStrategy`.
@propertyWrapper
public struct OptionalDateValueCodable<Formatter: DateValueCodableStrategy>: Sendable {
    public var wrappedValue: Date?

    public init(wrappedValue: Date?) {
        self.wrappedValue = wrappedValue
    }
}

extension OptionalDateValueCodable: Decodable where Formatter.RawValue: Decodable {
    public init(from decoder: Decoder) throws {
        let rawValue = try Formatter.RawValue?(from: decoder)
        if let rawValue {
            wrappedValue = try Formatter.decode(rawValue)
        } else {
            wrappedValue = nil
        }
    }
}

extension OptionalDateValueCodable: Encodable where Formatter.RawValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        guard let wrappedValue else {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
            return
        }

        let rawValue = Formatter.encode(wrappedValue)
        try rawValue.encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    public func decode<T>(
        _ type: OptionalDateValueCodable<T>.Type,
        forKey key: Self.Key
    ) throws -> OptionalDateValueCodable<T> where T.RawValue: Decodable {
        try decodeIfPresent(type, forKey: key) ?? OptionalDateValueCodable<T>(wrappedValue: nil)
    }

    public func decodeIfPresent<T>(
        _: OptionalDateValueCodable<T>.Type,
        forKey key: Self.Key
    ) throws -> OptionalDateValueCodable<T> where T.RawValue == String {
        let stringOptionalValue = try decodeIfPresent(String.self, forKey: key)

        guard let stringValue = stringOptionalValue else {
            return .init(wrappedValue: nil)
        }

        let dateValue = try T.decode(stringValue)
        return .init(wrappedValue: dateValue)
    }
}
