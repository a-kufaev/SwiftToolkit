//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2026 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

/// Observes values that the lossy `Codable` wrappers silently discard.
///
/// `@LossyCodableArray` and `@DefaultCodable` (including `@LossyOptionalCodable`) swallow decoding
/// failures by design, which makes a malformed payload indistinguishable from a legitimately empty or
/// absent one. Set a reporter on `JSONDecoder.userInfo[.lossyDecodingReporter]` to be notified of every
/// dropped element/value — the wrappers keep their tolerant behaviour, but the failure stops being silent.
public protocol LossyDecodingReporter: AnyObject, Sendable {

    /// Called for each value a lossy wrapper failed to decode and replaced with a fallback.
    ///
    /// - Parameters:
    ///   - error: The original decoding failure; its `codingPath` points to the offending field.
    ///   - codingPath: The path of the container that produced the failure.
    func lossyDecodingDidDrop(_ error: Error, codingPath: [CodingKey])
}

public extension CodingUserInfoKey {

    /// Slot for a ``LossyDecodingReporter`` on a decoder's `userInfo`.
    static let lossyDecodingReporter = CodingUserInfoKey(rawValue: "SwiftToolkit.LossyDecodingReporter")!
}
