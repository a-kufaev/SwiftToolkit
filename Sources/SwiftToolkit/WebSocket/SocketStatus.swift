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

extension WebSocket {
    public enum State: Equatable, Sendable {
        /// The socket is initialized and ready to connect
        case notConnected
        /// The socket is in the process of connecting
        case connecting
        /// The socket is connected
        case connected
        /// The socket is disconnected after being connected
        case disconnected
    }

    public enum StateChangedEvent: Equatable, Sendable {
        /// The socket is in the process of connecting
        case connecting
        /// The socket is connected
        case connected
        /// The socket is disconnected after being connected
        case disconnected(closeCode: URLSessionWebSocketTask.CloseCode?, reason: String?, error: Error?)

        public static func == (lhs: WebSocket.StateChangedEvent, rhs: WebSocket.StateChangedEvent) -> Bool {
            switch (lhs, rhs) {
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case let (
                .disconnected(lhsCloseCode, lhsReason, lhsError),
                .disconnected(rhsCloseCode, rhsReason, rhsError)
            ):
                return lhsCloseCode == rhsCloseCode
                    && lhsReason == rhsReason
                    && lhsError?.localizedDescription == rhsError?.localizedDescription
            default:
                return false
            }
        }
    }

    public enum Heartbeats: Sendable {
        case disabled
        case enabled(kind: Kind, every: Duration)

        public enum Kind: Sendable {
            case native
            case customMessage(any Encodable & Sendable)
        }
    }

    public enum Message: Sendable {
        /// A string message
        case string(String)
        /// A data message
        case data(Data)
        /// A message that could not be parsed
        case invalid(Error)
    }
}
