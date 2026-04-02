import AVFoundation
import UIKit

/// Manages video recording using AVCaptureMovieFileOutput with HEVC encoding.
public final class VideoRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {

    private let movieOutput = AVCaptureMovieFileOutput()
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    /// The capture output to add to the AVCaptureSession.
    public var output: AVCaptureMovieFileOutput { movieOutput }

    public override init() {
        super.init()
        movieOutput.maxRecordedDuration = CMTime(seconds: 5.0, preferredTimescale: 600)
    }

    /// Starts recording to a temporary file. Returns the file URL when recording finishes.
    public func startRecording() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("anlik_clip_\(UUID().uuidString).mp4")

        // Configure HEVC if available
        if let connection = movieOutput.connection(with: .video) {
            if movieOutput.availableVideoCodecTypes.contains(.hevc) {
                movieOutput.setOutputSettings(
                    [AVVideoCodecKey: AVVideoCodecType.hevc],
                    for: connection
                )
            }
            connection.videoOrientation = .portrait
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.recordingContinuation = continuation
            movieOutput.startRecording(to: fileUrl, recordingDelegate: self)
        }
    }

    /// Stops recording. The startRecording() continuation will resume.
    public func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    public var isRecording: Bool { movieOutput.isRecording }

    public var currentDuration: Double {
        movieOutput.recordedDuration.seconds
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error {
            recordingContinuation?.resume(throwing: error)
        } else {
            recordingContinuation?.resume(returning: outputFileURL)
        }
        recordingContinuation = nil
    }
}
