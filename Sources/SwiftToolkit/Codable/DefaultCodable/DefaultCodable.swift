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

// Reference: https://github.com/marksands/BetterCodable

/// Provides a default value for missing or invalid `Decodable` data.
///
/// `DefaultCodableStrategy` supplies a strategy type that the `DefaultCodable` property wrapper can use to provide a
/// reasonable default value when data is absent or fails decoding.
public protocol DefaultCodableStrategy {
    associatedtype DefaultValue: Decodable & Sendable

    /// The fallback value used when decoding fails.
    static var defaultValue: DefaultValue { get }
}

/// Decodes values with a reasonable default value.
///
/// `@DefaultCodable` attempts to decode a value and falls back to a default provided by the generic
/// `DefaultCodableStrategy`.
@propertyWrapper
public struct DefaultCodable<Default: DefaultCodableStrategy>: Sendable {
    public var wrappedValue: Default.DefaultValue

    public init(wrappedValue: Default.DefaultValue) {
        self.wrappedValue = wrappedValue
    }
}

extension DefaultCodable: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = (try? container.decode(Default.DefaultValue.self)) ?? Default.defaultValue
    }
}

extension DefaultCodable: Encodable where Default.DefaultValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension DefaultCodable: Equatable where Default.DefaultValue: Equatable {}
extension DefaultCodable: Hashable where Default.DefaultValue: Hashable {}

// MARK: - KeyedDecodingContainer

public protocol BoolCodableStrategy: DefaultCodableStrategy where DefaultValue == Bool {}

extension KeyedDecodingContainer {

    /// Default implementation of decoding a `DefaultCodable`.
    ///
    /// If the key is available decoding proceeds; otherwise the default strategy value is returned.
    public func decode<P>(_: DefaultCodable<P>.Type, forKey key: Key) throws -> DefaultCodable<P> {
        if let value = try decodeIfPresent(DefaultCodable<P>.self, forKey: key) {
            return value
        } else {
            return DefaultCodable(wrappedValue: P.defaultValue)
        }
    }

    /// Default implementation of decoding a `DefaultCodable` where its strategy is a `BoolCodableStrategy`.
    ///
    /// Tries to decode a `Bool` first, otherwise attempts `Int` or `String` when a `typeMismatch` decoding error
    /// occurs. This preserves the intended Boolean value when the provider sends different primitive types. If
    /// everything fails, defaults to the `defaultValue` provided by the strategy.
    public func decode<P: BoolCodableStrategy>(_: DefaultCodable<P>.Type, forKey key: Key) throws -> DefaultCodable<P> {
        do {
            let value = try decode(Bool.self, forKey: key)
            return DefaultCodable(wrappedValue: value)
        } catch {
            guard let decodingError = error as? DecodingError,
                  case .typeMismatch = decodingError else {
                return DefaultCodable(wrappedValue: P.defaultValue)
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: key),
               let bool = Bool(exactly: NSNumber(value: intValue)) {
                return DefaultCodable(wrappedValue: bool)
            } else if let stringValue = try? decodeIfPresent(String.self, forKey: key),
                      let bool = Bool(stringValue) {
                return DefaultCodable(wrappedValue: bool)
            } else {
                return DefaultCodable(wrappedValue: P.defaultValue)
            }
        }
    }
}
