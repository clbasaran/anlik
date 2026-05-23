import SwiftUI
import AVFoundation

/// Voice memo recorder pill shown alongside the photo preview. Owns the
/// AVAudioRecorder, mic permission flow, and 15-second auto-stop timer so
/// PreviewView doesn't carry that machinery for one optional feature.
///
/// The parent passes a `voiceData` binding — when the user finishes a
/// recording the bytes land there for upload alongside the photo. The parent
/// can also reset to nil (e.g. after sending) and the UI flips back to
/// "tap to record".
struct PreviewVoiceRecorder: View {
    /// Set when the user finishes a recording. Cleared by the parent after
    /// the photo upload consumes it.
    @Binding var voiceData: Data?
    let isUploading: Bool
    let showSuccess: Bool

    @State private var isRecording: Bool = false
    @State private var hasVoice: Bool = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioRecorder: AVAudioRecorder?
    /// Stored in IsolatedRef so a stray fire after deinit can't reach a dead view.
    private let recordingTimer = IsolatedRef<Timer?>(nil)
    @State private var showPermissionAlert: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if isRecording {
                    stopRecording()
                } else if hasVoice {
                    voiceData = nil
                    hasVoice = false
                    recordingDuration = 0
                } else {
                    Task { await beginRecordingWithPermissionCheck() }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isRecording ? "stop.fill" : hasVoice ? "xmark" : "mic.fill")
                        .font(.system(size: 14, weight: .bold))
                    if isRecording {
                        Text(String(format: "%.0f sn", recordingDuration))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    } else if hasVoice {
                        Text(String(format: "%.0f sn", recordingDuration))
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundColor(isRecording ? .white : hasVoice ? .white : .white.opacity(0.8))
                .padding(.horizontal, hasVoice || isRecording ? 16 : 12)
                .padding(.vertical, 12)
                .background(
                    isRecording ? Color.white.opacity(0.3) : hasVoice ? Color.white.opacity(0.2) : Color.white.opacity(0.15),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isRecording ? Color.white.opacity(0.5) : hasVoice ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isUploading || showSuccess)
            .accessibilityLabel(accessibilityLabelText)

            if hasVoice {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
        .alert(
            String(localized: "mikrofon erişimi gerekli"),
            isPresented: $showPermissionAlert
        ) {
            Button(String(localized: "ayarlar")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(String(localized: "vazgeç"), role: .cancel) {}
        } message: {
            Text(String(localized: "sesli yorum eklemek için mikrofona izin vermen lazım. ayarlardan açabilirsin."))
        }
        .onDisappear { stopRecordingIfNeeded() }
    }

    private var accessibilityLabelText: String {
        if isRecording { return String(localized: "Kaydı Durdur") }
        if hasVoice { return String(localized: "Sesli Yorumu Sil") }
        return String(localized: "Sesli Yorum Kaydet")
    }

    // MARK: - Permission & lifecycle

    @MainActor
    private func beginRecordingWithPermissionCheck() async {
        let app = AVAudioApplication.shared
        switch app.recordPermission {
        case .granted:
            startRecording()
        case .denied:
            showPermissionAlert = true
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            if granted { startRecording() } else { showPermissionAlert = true }
        @unknown default:
            showPermissionAlert = true
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.record()
            audioRecorder = recorder
            isRecording = true
            recordingDuration = 0
            HapticsManager.playImpact(style: .medium)

            recordingTimer.value = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    recordingDuration = audioRecorder?.currentTime ?? 0
                    if recordingDuration >= 15 { stopRecording() }
                }
            }
        } catch { return }
    }

    private func stopRecording() {
        recordingTimer.value?.invalidate()
        recordingTimer.value = nil
        guard let recorder = audioRecorder else { return }
        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        HapticsManager.playNotification(type: .success)

        if let data = try? Data(contentsOf: url), recordingDuration >= 0.5 {
            voiceData = data
            hasVoice = true
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func stopRecordingIfNeeded() {
        guard isRecording else { return }
        stopRecording()
    }
}
