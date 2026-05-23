import SwiftUI
import WatchKit

/// Renders the most recently received photo on the watch. Bytes live in the
/// App Group container (written by `PhoneSessionManager`) so this view and
/// the photo complication read the same source of truth.
struct LatestPhotoView: View {
    @EnvironmentObject var store: WatchDataStore
    var onBack: (() -> Void)?

    /// Cache the decoded UIImage so SwiftUI doesn't re-read+decode from disk
    /// on every `body` recompute. Keyed by URL so it invalidates when a new
    /// photo arrives.
    @State private var cachedImage: UIImage?
    @State private var cachedURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: WatchBrand.Spacing.hairline) {
                backRow

                if let image = cachedImage {
                    photoContent(image: image)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, WatchBrand.Spacing.xxs)
        }
        .onAppear { loadImageIfNeeded() }
        .onChange(of: store.latestPhotoFileURL) { _, _ in loadImageIfNeeded() }
    }

    // MARK: - Photo Content

    private func photoContent(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: WatchBrand.Radius.md))

            // Top + bottom gradients keep text legible without color tint.
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.5), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 36)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 50)
            }
            .clipShape(RoundedRectangle(cornerRadius: WatchBrand.Radius.md))

            VStack {
                HStack {
                    Spacer()
                    Text(WatchBrand.name)
                        .font(WatchBrand.micro(size: 9))
                        .foregroundStyle(WatchBrand.textSecondary)
                }
                .padding(.horizontal, WatchBrand.Spacing.sm)
                .padding(.top, WatchBrand.Spacing.xxs)

                Spacer()

                if let photoInfo = store.latestPhotos.first {
                    HStack {
                        VStack(alignment: .leading, spacing: WatchBrand.Spacing.hairline) {
                            if !photoInfo.senderName.isEmpty {
                                Text(photoInfo.senderName)
                                    .font(WatchBrand.headline(size: 11))
                                    .foregroundStyle(WatchBrand.textPrimary)
                                    .lineLimit(1)
                            }
                            if let city = photoInfo.cityName {
                                HStack(spacing: WatchBrand.Spacing.hairline) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 7))
                                    Text(city)
                                        .font(.system(size: 9, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(WatchBrand.textPrimary.opacity(0.75))
                            }
                            Text(photoInfo.timestamp, style: .relative)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(WatchBrand.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, WatchBrand.Spacing.sm)
                    .padding(.bottom, WatchBrand.Spacing.sm)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(photoAccessibilityLabel)
        .accessibilityHint(String(localized: "watch.a11y.photo.hint"))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: WatchBrand.Spacing.sm) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(WatchBrand.title(size: 24))
                .foregroundStyle(WatchBrand.textTertiary)

            Text(String(localized: "watch.empty.photo"))
                .font(WatchBrand.caption())
                .foregroundStyle(WatchBrand.textSecondary)

            Text(store.emptyStateHint)
                .font(WatchBrand.micro(size: 9))
                .foregroundStyle(WatchBrand.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                WatchDataStore.shared.markSyncStarted()
                PhoneSessionManager.shared.requestSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(WatchBrand.micro())
            }
            .buttonStyle(.plain)
            .foregroundStyle(WatchBrand.textTertiary)
            .accessibilityLabel(String(localized: "watch.action.refresh"))
        }
        .padding(.top, WatchBrand.Spacing.lg)
    }

    // MARK: - Back

    private var backRow: some View {
        HStack {
            Button {
                onBack?()
            } label: {
                HStack(spacing: WatchBrand.Spacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(String(localized: "watch.nav.home"))
                        .font(WatchBrand.micro(size: 11))
                }
                .foregroundStyle(WatchBrand.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "watch.a11y.back"))
            Spacer()
        }
    }

    // MARK: - Image loader

    private func loadImageIfNeeded() {
        guard let url = store.latestPhotoFileURL else {
            cachedImage = nil
            cachedURL = nil
            return
        }
        if url == cachedURL && cachedImage != nil { return }

        Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                self.cachedImage = image
                self.cachedURL = url
            }
        }
    }

    // MARK: - Accessibility

    private var photoAccessibilityLabel: String {
        guard let photo = store.latestPhotos.first else {
            return String(localized: "watch.empty.photo")
        }
        var parts: [String] = []
        if !photo.senderName.isEmpty { parts.append(photo.senderName) }
        if let city = photo.cityName, !city.isEmpty { parts.append(city) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    LatestPhotoView(onBack: {})
        .environmentObject(WatchDataStore.shared)
}
