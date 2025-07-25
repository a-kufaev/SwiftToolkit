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

/// A protocol that implements the Builder pattern for fluent property configuration.
///
/// Use this protocol when you need to configure value-type properties from outside the value's scope.
/// Example: `map { $0.radius = radius }`
public protocol Buildable {
    func map(_ closure: (inout Self) -> Void) -> Self
}

extension Buildable {
    public func map(_ closure: (inout Self) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
    }
}
