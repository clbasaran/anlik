import Foundation
import AVFoundation
import UIKit

/// Builds Boomerang-style videos: takes a source video and produces a new
/// video that plays forward, then reverse, then forward again — like an
/// Instagram Boomerang. Pure-ish (no UI), but uses AVFoundation so it's
/// effectively integration-tested rather than unit-tested.
public enum BoomerangBuilder {

    public enum Error: Swift.Error, LocalizedError {
        case readerCreateFailed
        case writerCreateFailed
        case noVideoTrack
        case exportFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .readerCreateFailed: return "Video okunamıyor."
            case .writerCreateFailed: return "Video yazılamıyor."
            case .noVideoTrack: return "Geçerli video bulunamadı."
            case .exportFailed(let m): return "Boomerang oluşturulamadı: \(m)"
            case .cancelled: return "İptal edildi."
            }
        }
    }

    /// Build a boomerang video from a source video URL.
    ///
    /// Output is forward + reverse concatenated. The reversed segment skips the
    /// first frame so the stitch point doesn't show a single duplicated frame
    /// (which causes a visible "freeze" on cheap implementations).
    ///
    /// `speed` multiplier scales the entire output's playback rate. 1.5x makes
    /// it feel snappier (Instagram-default-feel); 2x is "energetic"; values
    /// outside [0.5, 3.0] are clamped.
    ///
    /// - Parameters:
    ///   - sourceURL: Local video file URL
    ///   - outputURL: Where to write the boomerang
    ///   - speed: Playback speed multiplier (default 1.5x)
    /// - Returns: outputURL on success
    public static func makeBoomerang(
        from sourceURL: URL,
        to outputURL: URL,
        speed: Double = 1.5
    ) async throws -> URL {
        let speed = max(0.5, min(3.0, speed))
        try? FileManager.default.removeItem(at: outputURL)

        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw Error.noVideoTrack
        }
        let duration = try await asset.load(.duration)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // Reverse the source first into a temp file
        let reversedURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent("reversed_\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: reversedURL) }
        try await reverseVideo(asset: asset, to: reversedURL)

        let reversedAsset = AVURLAsset(url: reversedURL)
        guard let reversedTrack = try await reversedAsset.loadTracks(withMediaType: .video).first else {
            throw Error.noVideoTrack
        }
        let reversedDuration = try await reversedAsset.load(.duration)

        // Build composition: forward (full) + reversed (skip first frame to
        // avoid duplicate-frame freeze at the stitch point).
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw Error.writerCreateFailed
        }

        try track.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )

        // Estimate one-frame duration (assume 30fps if unknown) and trim it
        // from the start of the reversed segment.
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let fps = nominalFrameRate > 0 ? Double(nominalFrameRate) : 30.0
        let oneFrame = CMTime(seconds: 1.0 / fps, preferredTimescale: 600)
        let reversedStart = oneFrame
        let reversedTrimmedDuration = max(.zero, CMTimeSubtract(reversedDuration, oneFrame))

        if reversedTrimmedDuration > .zero {
            try track.insertTimeRange(
                CMTimeRange(start: reversedStart, duration: reversedTrimmedDuration),
                of: reversedTrack,
                at: duration
            )
        } else {
            // Source is too short to trim — fall back to full reverse
            try track.insertTimeRange(
                CMTimeRange(start: .zero, duration: reversedDuration),
                of: reversedTrack,
                at: duration
            )
        }

        track.preferredTransform = preferredTransform

        // Apply playback speed by scaling the entire timeline
        if abs(speed - 1.0) > 0.01 {
            let total = composition.duration
            let scaledTotal = CMTime(seconds: total.seconds / speed, preferredTimescale: 600)
            track.scaleTimeRange(
                CMTimeRange(start: .zero, duration: total),
                toDuration: scaledTotal
            )
        }

        // Pick an export preset that caps the output at 1080p. Highest-quality
        // would faithfully preserve a 4K source, but a 4K boomerang chews up
        // memory during compose+reverse and produces multi-hundred-MB profile
        // loops nobody asked for. 1080p is plenty for the loop's playback size.
        let naturalSize = try await videoTrack.load(.naturalSize)
        let longEdge = max(abs(naturalSize.width), abs(naturalSize.height))
        let preset: String
        if longEdge > 1920 {
            preset = AVAssetExportPreset1920x1080
        } else if longEdge > 1280 {
            preset = AVAssetExportPreset1280x720
        } else {
            preset = AVAssetExportPresetHighestQuality
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: preset
        ) else {
            throw Error.exportFailed("AVAssetExportSession init failed")
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .cancelled:
                    continuation.resume(throwing: Error.cancelled)
                case .failed:
                    let msg = exporter.error?.localizedDescription ?? "unknown"
                    continuation.resume(throwing: Error.exportFailed(msg))
                default:
                    continuation.resume(throwing: Error.exportFailed("status \(exporter.status.rawValue)"))
                }
            }
        }
    }

    /// Reverse a video by reading frames in reverse and writing them out.
    /// Audio is dropped (Boomerangs are typically silent).
    private static func reverseVideo(asset: AVAsset, to outputURL: URL) async throws {
        try? FileManager.default.removeItem(at: outputURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw Error.noVideoTrack
        }

        // Read all sample buffers
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(trackOutput)
        guard reader.startReading() else {
            throw Error.readerCreateFailed
        }

        var samples: [CMSampleBuffer] = []
        while let sample = trackOutput.copyNextSampleBuffer() {
            samples.append(sample)
        }
        guard !samples.isEmpty else {
            throw Error.exportFailed("no frames read")
        }

        // Determine timing from the original samples
        let timestamps = samples.map { CMSampleBufferGetPresentationTimeStamp($0) }
        let durations = samples.indices.map { i -> CMTime in
            if i + 1 < timestamps.count {
                return CMTimeSubtract(timestamps[i + 1], timestamps[i])
            }
            return CMTimeMake(value: 1, timescale: 30)
        }

        // Reverse the frames; reuse durations in order so total length matches.
        let reversedSamples = samples.reversed()

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let dimensions = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let writerSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height)
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerSettings)
        writerInput.transform = transform
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(dimensions.width),
                kCVPixelBufferHeightKey as String: Int(dimensions.height)
            ]
        )
        guard writer.canAdd(writerInput) else {
            throw Error.writerCreateFailed
        }
        writer.add(writerInput)
        guard writer.startWriting() else {
            throw Error.writerCreateFailed
        }
        writer.startSession(atSourceTime: .zero)

        var currentTime = CMTime.zero
        for (i, sample) in reversedSamples.enumerated() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            // Wait until ready
            while !writerInput.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 5_000_000) // 5 ms
            }
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime)
            // Use forward duration order — preserves natural timing
            currentTime = CMTimeAdd(currentTime, durations[i])
        }
        writerInput.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        if writer.status == .failed {
            throw Error.exportFailed(writer.error?.localizedDescription ?? "writer failed")
        }
    }

    /// Extract the first frame as a JPEG thumbnail for fast preview.
    public static func thumbnail(from videoURL: URL) async throws -> Data {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        let cgImage = try await generator.image(at: .zero).image
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.7) else {
            throw Error.exportFailed("thumbnail jpeg encode failed")
        }
        return data
    }
}
