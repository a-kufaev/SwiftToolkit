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

public typealias SafetyEnumType = CaseIterable & Decodable & RawRepresentable & Sendable

/// A forward-compatible enum that falls back to a `failure` case when decoding an unknown raw value.
///
/// Conform an enum to `SafetyEnum` and provide a `failure` case. Decoding a raw value that does not
/// match any known case yields `failure` instead of throwing — useful for tolerating new server-side
/// values without breaking older clients.
public protocol SafetyEnum: SafetyEnumType where RawValue: Decodable {
    static var failure: Self { get }
}

extension SafetyEnum {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(RawValue.self)

        if let knownCase = Self(rawValue: raw) {
            self = knownCase
        } else {
            self = Self.failure
        }
    }
}
