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

#if canImport(UIKit)
import AVFoundation
import Foundation
@testable import SwiftToolkitVideo
import Testing

@Suite("LoopingVideoPlayerModel")
@MainActor
struct LoopingVideoPlayerModelTests {

    @Test("currentURL is available synchronously right after setVideo")
    func currentURLIsAvailableSynchronously() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()

        model.setVideo(url: url)

        #expect(model.currentURL == url)
    }

    @Test("currentURL is nil before setVideo and again after reset")
    func currentURLFollowsTheVideoLifecycle() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()
        #expect(model.currentURL == nil)

        model.setVideo(url: url)
        #expect(model.currentURL == url)

        model.reset()
        #expect(model.currentURL == nil)
    }

    @Test("the template item is never enqueued")
    func templateItemIsNeverEnqueued() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()
        let template = AVPlayerItem(url: url)

        model.setVideo(item: template)
        try await waitForLoopingItems(of: model)

        #expect(model.player.items().allSatisfy { $0 !== template })
        #expect(model.player.currentItem !== template)
    }

    @Test("the buffer preference reaches every replica when set after setVideo")
    func bufferPreferenceReachesReplicasWhenSetAfterSetVideo() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()

        model.setVideo(url: url)
        model.setPreferredForwardBufferDuration(5)
        let items = try await waitForLoopingItems(of: model)

        #expect(items.allSatisfy { $0.preferredForwardBufferDuration == 5 })
    }

    @Test("the buffer preference reaches every replica when set before setVideo")
    func bufferPreferenceReachesReplicasWhenSetBeforeSetVideo() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()

        model.setPreferredForwardBufferDuration(1)
        model.setVideo(url: url)
        let items = try await waitForLoopingItems(of: model)

        #expect(items.allSatisfy { $0.preferredForwardBufferDuration == 1 })
    }

    @Test("a nil buffer preference restores the system default")
    func nilBufferPreferenceRestoresTheSystemDefault() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()

        model.setVideo(url: url)
        model.setPreferredForwardBufferDuration(5)
        let items = try await waitForLoopingItems(of: model)
        #expect(items.allSatisfy { $0.preferredForwardBufferDuration == 5 })

        model.setPreferredForwardBufferDuration(nil)

        #expect(items.allSatisfy { $0.preferredForwardBufferDuration == .zero })
    }

    @Test("reset empties the queue and the model can be reused afterwards")
    func resetEmptiesTheQueueAndTheModelStaysReusable() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()

        model.setVideo(url: url)
        try await waitForLoopingItems(of: model)

        model.reset()
        #expect(model.player.items().isEmpty)

        model.setVideo(url: url)
        let items = try await waitForLoopingItems(of: model)
        #expect(items.isEmpty == false)
    }

    @Test("play right after setVideo starts looping playback")
    func playRightAfterSetVideoStartsPlayback() async throws {
        let url = try await LoopingVideoFixture.url()
        let model = LoopingVideoPlayerModel()

        model.setVideo(url: url)
        model.play()

        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline, model.player.timeControlStatus != .playing {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(model.player.timeControlStatus == .playing)
    }

    @discardableResult
    private func waitForLoopingItems(
        of model: LoopingVideoPlayerModel,
        timeout: Duration = .seconds(5)
    ) async throws -> [AVPlayerItem] {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            let items = model.player.items()
            if items.isEmpty == false {
                try await Task.sleep(for: .milliseconds(50))
                return model.player.items()
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("AVPlayerLooper did not populate the queue within \(timeout)")
        return []
    }
}

@MainActor
private enum LoopingVideoFixture {

    private static var cached: URL?

    static func url() async throws -> URL {
        if let cached { return cached }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftToolkitLoopingFixture-\(UUID().uuidString).mp4")
        try await write(to: url)
        cached = url
        return url
    }

    private static func write(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 160,
            AVVideoHeightKey: 90
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<30 {
            while input.isReadyForMoreMediaData == false {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard let pool = adaptor.pixelBufferPool else { continue }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { continue }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }

        input.markAsFinished()
        await writer.finishWriting()
    }
}
#endif
