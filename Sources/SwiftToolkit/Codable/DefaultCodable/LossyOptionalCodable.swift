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

/// Provides `nil` as a fallback when optional decoding fails.
public struct DefaultNilCodableStrategy<T: Decodable>: DefaultCodableStrategy {
    public static var defaultValue: T? { nil }
}

/// Decodes optional types, defaulting to `nil` instead of throwing an error.
///
/// `@LossyOptionalCodable` decodes optionals and defaults to `nil` when decoding fails (e.g. decoding a non-URL string
/// to the `URL` type).
public typealias LossyOptionalCodable<T> = DefaultCodable<DefaultNilCodableStrategy<T>> where T: Decodable
