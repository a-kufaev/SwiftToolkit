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

/// Decodes arrays while silently dropping invalid elements.
///
/// `@LossyCodableArray` decodes arrays and filters out elements that fail to decode.
///
/// This is useful if the Array is intended to contain non-optional types.
@propertyWrapper
public struct LossyCodableArray<T: Sendable>: Sendable {
    public var wrappedValue: [T]

    public init(wrappedValue: [T]) {
        self.wrappedValue = wrappedValue
    }
}

extension LossyCodableArray: Decodable where T: Decodable {
    private struct AnyDecodableValue: Decodable {}

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        var elements: [T] = []
        while !container.isAtEnd {
            do {
                let value = try container.decode(T.self)
                elements.append(value)
            } catch {
                (decoder.userInfo[.lossyDecodingReporter] as? LossyDecodingReporter)?
                    .lossyDecodingDidDrop(error, codingPath: container.codingPath)
                _ = try? container.decode(AnyDecodableValue.self)
            }
        }

        wrappedValue = elements
    }
}

extension LossyCodableArray: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension LossyCodableArray: Equatable where T: Equatable {}
extension LossyCodableArray: Hashable where T: Hashable {}

// MARK: - KeyedDecodingContainer

extension KeyedDecodingContainer {

    /// A missing key decodes as an empty array: an absent list and an empty one mean the same
    /// thing to a lossy field, and the synthesized `Decodable` would otherwise throw on the key.
    public func decode<T: Decodable>(_: LossyCodableArray<T>.Type, forKey key: Key) throws -> LossyCodableArray<T> {
        try decodeIfPresent(LossyCodableArray<T>.self, forKey: key) ?? LossyCodableArray(wrappedValue: [])
    }
}
