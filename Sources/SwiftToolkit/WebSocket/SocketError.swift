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

public enum WebSocketError: Error, Sendable {
    case alreadyConnectedOrConnecting
    case notConnected
    case cannotParseMessageAsJSON(String)
    case invalidMessage(Error)
}
