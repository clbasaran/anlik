import SwiftUI
import AVFoundation
import PhotosUI

/// Records (or picks) a short video, optionally converts it to Boomerang,
/// and uploads it to the given slot. Presented as a sheet from EditProfileView
/// or the gallery slot tap.
public struct ProfileLoopRecorderView: View {
    let userId: String
    let slot: Int
    let existing: ProfileLoop?
    let onSaved: (ProfileLoop) -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceVideoURL: URL?
    @State private var processedVideoURL: URL?
    @State private var thumbnailData: Data?
    @State private var duration: Double = 0
    @State private var isBoomerang = true
    @State private var speed: Double = 1.5  // Instagram-default-feel
    @State private var isProcessing = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showInAppCamera = false

    /// Hard cap on the source video used for a profile loop.
    /// Boomerang doubles this (forward + reverse) → max ~4 sec output loop;
    /// at 1.5x speed → ~2.5 sec final output, which feels like Instagram's.
    private let maxSourceDuration: TimeInterval = 2.0

    /// Available speed options for the boomerang playback.
    private let speedOptions: [Double] = [1.0, 1.5, 2.0]

    public init(
        userId: String,
        slot: Int,
        existing: ProfileLoop? = nil,
        onSaved: @escaping (ProfileLoop) -> Void,
        onDeleted: @escaping () -> Void = {}
    ) {
        self.userId = userId
        self.slot = slot
        self.existing = existing
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer()
                    previewArea
                        .frame(maxWidth: 280)
                    Spacer()
                    controls
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
            .navigationTitle(String(localized: "Slot \(slot + 1)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Vazgeç")) { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                if existing != nil && processedVideoURL == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            Task { await deleteCurrent() }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red.opacity(0.8))
                        .disabled(isUploading)
                    }
                }
            }
            .errorToast(Binding(
                get: { errorMessage },
                set: { errorMessage = $0 }
            ))
            .fullScreenCover(isPresented: $showInAppCamera) {
                ProfileLoopCameraView(
                    onCaptured: { url in
                        showInAppCamera = false
                        sourceVideoURL = url
                        Task { await processCurrentSource() }
                    },
                    onCancel: {
                        showInAppCamera = false
                    }
                )
            }
        }
    }

    // MARK: - Preview area

    @ViewBuilder
    private var previewArea: some View {
        if isProcessing {
            VStack(spacing: 14) {
                ProgressView().tint(.white)
                Text(String(localized: "Boomerang oluşturuluyor..."))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 280, height: 380)
        } else if let url = processedVideoURL {
            // Show processed local file in the same player as the gallery
            let preview = ProfileLoop(
                id: ProfileLoop.id(forSlot: slot),
                slot: slot,
                videoUrl: url.absoluteString,
                thumbnailUrl: nil,
                duration: duration,
                isBoomerang: isBoomerang
            )
            ProfileLoopPlayerView(loop: preview, cornerRadius: 18, aspectRatio: 3 / 4)
        } else if let existing {
            ProfileLoopPlayerView(loop: existing, cornerRadius: 18, aspectRatio: 3 / 4)
        } else {
            emptyPreview
        }
    }

    private var emptyPreview: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .frame(width: 280, height: 380)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 38))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(String(localized: "kısa bir video seç"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if processedVideoURL != nil {
            VStack(spacing: 12) {
                // Boomerang on/off
                Toggle(isOn: $isBoomerang) {
                    HStack(spacing: 8) {
                        Image(systemName: "infinity")
                        Text(String(localized: "Boomerang (ileri-geri-döngü)"))
                    }
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .medium))
                }
                .tint(.white)
                .onChange(of: isBoomerang) { _, _ in
                    Task { await reprocess() }
                }

                // Speed picker — only meaningful for boomerangs
                if isBoomerang {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(String(localized: "hız"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(speedOptions, id: \.self) { option in
                                Button {
                                    HapticsManager.playSelection()
                                    speed = option
                                    Task { await reprocess() }
                                } label: {
                                    Text(speedLabel(option))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(speed == option ? .black : .white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(speed == option ? Color.white : Color.white.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Primary CTA
                Button {
                    Task { await uploadProcessed() }
                } label: {
                    HStack {
                        if isUploading { ProgressView().tint(.black) }
                        else { Text(String(localized: "Profile ekle")).font(.system(size: 16, weight: .semibold)) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
                }
                .disabled(isUploading)

                // Secondary: re-pick
                Button {
                    sourceVideoURL = nil
                    processedVideoURL = nil
                    thumbnailData = nil
                    pickerItem = nil
                } label: {
                    Text(String(localized: "Yeniden çek / seç"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
        } else {
            VStack(spacing: 10) {
                // In-app camera (primary CTA)
                Button {
                    HapticsManager.playImpact(style: .light)
                    showInAppCamera = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text(String(localized: "kameradan çek"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
                }

                // Gallery (secondary)
                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(String(localized: "galeriden seç"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
                    .font(.system(size: 15, weight: .medium))
                }
                .onChange(of: pickerItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task { await loadAndProcess(item: item) }
                }

                Text(String(localized: "en fazla 2 saniye"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Pipeline

    private func loadAndProcess(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = String(localized: "Video yüklenemedi.")
                return
            }
            // Write to temp file
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("loop_src_\(UUID().uuidString).mp4")
            try data.write(to: tmp)
            sourceVideoURL = tmp
            await processCurrentSource()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processCurrentSource() async {
        guard let src = sourceVideoURL else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Step 1: trim source to 2 seconds max if needed
            let asset = AVURLAsset(url: src)
            let originalDuration = try await asset.load(.duration).seconds
            let trimmedSrc: URL
            if originalDuration > maxSourceDuration {
                trimmedSrc = FileManager.default.temporaryDirectory
                    .appendingPathComponent("loop_trim_\(UUID().uuidString).mp4")
                try await trimVideo(asset: asset, duration: maxSourceDuration, to: trimmedSrc)
            } else {
                trimmedSrc = src
            }

            let trimmedAsset = AVURLAsset(url: trimmedSrc)
            let clippedDuration = min(try await trimmedAsset.load(.duration).seconds, maxSourceDuration)
            // Boomerang doubles the timeline (forward + reverse — minus one frame),
            // then speed scales the whole thing. So final duration = (2 * src) / speed.
            let baseLoopDuration = isBoomerang ? clippedDuration * 2 : clippedDuration
            duration = isBoomerang ? baseLoopDuration / speed : baseLoopDuration

            let outURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("loop_out_\(UUID().uuidString).mp4")

            if isBoomerang {
                _ = try await BoomerangBuilder.makeBoomerang(from: trimmedSrc, to: outURL, speed: speed)
            } else {
                try? FileManager.default.copyItem(at: trimmedSrc, to: outURL)
            }
            processedVideoURL = outURL
            thumbnailData = try? await BoomerangBuilder.thumbnail(from: outURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Human-friendly speed label ("1×", "1.5×", "2×").
    private func speedLabel(_ value: Double) -> String {
        if abs(value - 1.0) < 0.01 { return "1×" }
        if abs(value - 1.5) < 0.01 { return "1.5×" }
        if abs(value - 2.0) < 0.01 { return "2×" }
        return String(format: "%.1f×", value)
    }

    /// Trim a video asset to the first `duration` seconds, exporting MP4.
    private func trimVideo(asset: AVAsset, duration: TimeInterval, to outURL: URL) async throws {
        try? FileManager.default.removeItem(at: outURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw NSError(domain: "ProfileLoopRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Export session oluşturulamadı"])
        }
        exporter.outputURL = outURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        let endTime = CMTime(seconds: duration, preferredTimescale: 600)
        exporter.timeRange = CMTimeRange(start: .zero, duration: endTime)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                if exporter.status == .completed {
                    cont.resume()
                } else {
                    cont.resume(throwing: exporter.error ?? NSError(domain: "ProfileLoopRecorder", code: 2))
                }
            }
        }
    }

    private func reprocess() async {
        guard sourceVideoURL != nil else { return }
        if let old = processedVideoURL { try? FileManager.default.removeItem(at: old) }
        await processCurrentSource()
    }

    private func uploadProcessed() async {
        guard let url = processedVideoURL else { return }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = String(localized: "Video okunamadı.")
            return
        }
        isUploading = true
        defer { isUploading = false }

        do {
            let loop = try await ProfileLoopService.shared.uploadLoop(
                userId: userId,
                slot: slot,
                videoData: data,
                thumbnailData: thumbnailData,
                duration: duration,
                isBoomerang: isBoomerang
            )
            HapticsManager.playNotification(type: .success)
            onSaved(loop)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HapticsManager.playNotification(type: .error)
        }
    }

    private func deleteCurrent() async {
        do {
            try await ProfileLoopService.shared.deleteLoop(userId: userId, slot: slot)
            HapticsManager.playNotification(type: .success)
            onDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
