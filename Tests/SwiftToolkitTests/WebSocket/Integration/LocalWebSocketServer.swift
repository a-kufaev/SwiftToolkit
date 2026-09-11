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

import Foundation
import Network

/// Loopback WebSocket server for integration tests. It accepts every client and holds the connection until the
/// test closes it with a close frame or drops it without one. With `upgrade: false` it is a bare TCP listener that
/// closes every accepted connection at once, so a client's handshake fails.
final class LocalWebSocketServer: @unchecked Sendable {

    private(set) var port: UInt16 = .zero

    private let listener: NWListener
    private let upgrade: Bool
    private let queue = DispatchQueue(label: "LocalWebSocketServer")
    private let lock = NSLock()
    private var connections: [NWConnection] = []

    private init(listener: NWListener, upgrade: Bool) {
        self.listener = listener
        self.upgrade = upgrade
    }

    static func start(upgrade: Bool = true) async throws -> LocalWebSocketServer {
        let parameters = NWParameters.tcp
        if upgrade {
            let options = NWProtocolWebSocket.Options()
            options.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.insert(options, at: .zero)
        }
        let server = LocalWebSocketServer(listener: try NWListener(using: parameters, on: .any), upgrade: upgrade)
        try await server.run()
        return server
    }

    var connectionCount: Int {
        lock.withLock { connections.count }
    }

    /// Sends a close frame to every client, then lets the OS finish the handshake.
    func closeAll() {
        for connection in lock.withLock({ connections }) {
            let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
            metadata.closeCode = .protocolCode(.normalClosure)
            let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
            connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    /// Kills every client connection without a close frame.
    func dropAll() {
        for connection in lock.withLock({ connections }) {
            connection.forceCancel()
        }
    }

    func stop() {
        dropAll()
        listener.cancel()
    }

    private func run() async throws {
        let ready = ReadySignal()
        listener.stateUpdateHandler = { [weak self, listener] state in
            switch state {
            case .ready:
                self?.port = listener.port?.rawValue ?? .zero
                ready.resume(with: .success(()))
            case let .failed(error):
                ready.resume(with: .failure(error))
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        try await ready.wait()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        guard upgrade else {
            connection.cancel()
            return
        }
        lock.withLock { connections.append(connection) }
        receiveLoop(connection)
    }

    private func receiveLoop(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] _, _, _, error in
            guard error == nil else { return }
            self?.receiveLoop(connection)
        }
    }
}

/// Resumes a single waiter exactly once, from whichever callback fires first.
private final class ReadySignal: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?
    private var continuation: CheckedContinuation<Void, Error>?

    func resume(with result: Result<Void, Error>) {
        let continuation: CheckedContinuation<Void, Error>? = lock.withLock {
            guard self.result == nil else { return nil }
            self.result = result
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }

    func wait() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let stored: Result<Void, Error>? = lock.withLock {
                if let stored = self.result { return stored }
                self.continuation = continuation
                return nil
            }
            if let stored {
                continuation.resume(with: stored)
            }
        }
    }
}
