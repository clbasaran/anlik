import SwiftUI

/// GIPHY sticker picker — Instagram-style animated sticker search & selection.
/// Presented as a sheet from ChatView when user taps "Çıkartma ekle" in context menu.
struct GiphyStickerPicker: View {
    let onSelect: (String, String) -> Void // (originalUrl, mediaId)
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var stickers: [GiphySticker] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    TextField("GIPHY'de ara...", text: $searchText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Grid
                ScrollView {
                    if isLoading && stickers.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if stickers.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "face.dashed")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("çıkartma bulunamadı")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(stickers) { sticker in
                                stickerCell(sticker)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    }
                }

                // GIPHY Attribution (required)
                HStack(spacing: 6) {
                    Text("Powered by")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("GIPHY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.vertical, 8)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            .navigationTitle("Çıkartma Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .task { await loadTrending() }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s debounce
                guard !Task.isCancelled else { return }
                await search(query: newValue)
            }
        }
    }

    // MARK: - Sticker Cell

    @ViewBuilder
    private func stickerCell(_ sticker: GiphySticker) -> some View {
        Button {
            HapticsManager.playImpact(style: .medium)
            onSelect(sticker.originalUrl, sticker.id)
            dismiss()
        } label: {
            AnimatedGIFView(url: sticker.previewUrl)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadTrending() async {
        isLoading = true
        do {
            stickers = try await GiphyService.shared.trendingStickers()
        } catch {
            #if DEBUG
            AppLogger.ui.error("GIPHY trending error: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        isLoading = false
    }

    private func search(query: String) async {
        isLoading = true
        do {
            stickers = try await GiphyService.shared.searchStickers(query: query)
        } catch {
            #if DEBUG
            AppLogger.ui.error("GIPHY search error: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        isLoading = false
    }
}
