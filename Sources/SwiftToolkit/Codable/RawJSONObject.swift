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

/// Decodes an arbitrary, untyped JSON value into a Swift `Any`.
///
/// Handles strings, integers, doubles, booleans, nested objects (`[String: Any]`), arrays (`[Any]`),
/// and `null` (decoded as `NSNull`). Useful for dynamic JSON whose shape is not known ahead of time.
public struct RawJSONObject: Decodable {

    public let value: Any

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) { self.value = value; return }
        if let value = try? container.decode(Int.self) { self.value = value; return }
        if let value = try? container.decode(Double.self) { self.value = value; return }
        if let value = try? container.decode(Bool.self) { self.value = value; return }

        if let value = try? container.decode([String: RawJSONObject].self) {
            self.value = value.mapValues { $0.value }
            return
        }

        if let value = try? container.decode([RawJSONObject].self) {
            self.value = value.map(\.value)
            return
        }

        value = NSNull()
    }
}
