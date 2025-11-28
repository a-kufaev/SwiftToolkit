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

// MARK: - False

public struct DefaultFalseCodableStrategy: BoolCodableStrategy {
    public static var defaultValue: Bool { false }
}

/// Decodes Bools defaulting to `false` when missing or invalid.
///
/// `@DefaultFalseCodable` decodes Bools and defaults the value to `false` if the decoder cannot decode the value.
public typealias DefaultFalseCodable = DefaultCodable<DefaultFalseCodableStrategy>

// MARK: - True

public struct DefaultTrueCodableStrategy: BoolCodableStrategy {
    public static var defaultValue: Bool { true }
}

/// Decodes Bools defaulting to `true` when missing or invalid.
///
/// `@DefaultTrueCodable` decodes Bools and defaults the value to `true` if the decoder cannot decode the value.
public typealias DefaultTrueCodable = DefaultCodable<DefaultTrueCodableStrategy>
