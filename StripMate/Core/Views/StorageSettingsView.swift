import SwiftUI
import SwiftData

// MARK: - Storage Settings View

struct StorageSettingsView: View {
    @Query(sort: \Strip.timestamp, order: .reverse) private var localStrips: [Strip]
    @State private var cacheSize: String = String(localized: "hesaplanıyor...")
    @State private var isClearing = false
    @State private var showClearAlert = false
    @State private var clearSuccess = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadTotal: Int = 0
    @State private var downloadDone: Int = 0
    @State private var downloadSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cache Info
                storageSection(title: String(localized: "önbellek")) {
                    HStack(spacing: 14) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 22)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("görsel önbelleği")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Text(cacheSize)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        
                        Spacer()
                        
                        Button {
                            showClearAlert = true
                        } label: {
                            if isClearing {
                                ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.8)
                            } else {
                                Text("temizle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                        .disabled(isClearing)
                    }
                    .padding(.vertical, 4)
                }
                
                // Data Saver
                storageSection(title: String(localized: "veri kullanımı")) {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 22)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("veri tasarrufu modu")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Text("feed'de küçük görseller yüklenir")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "data_saver_mode") },
                            set: { UserDefaults.standard.set($0, forKey: "data_saver_mode") }
                        ))
                        .tint(.white.opacity(0.5))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
                
                // Auto Download
                storageSection(title: String(localized: "otomatik indirme")) {
                    autoDownloadRow(
                        label: String(localized: "wi-fi'da otomatik indir"),
                        key: "auto_download_wifi",
                        defaultValue: true
                    )
                    divider
                    autoDownloadRow(
                        label: String(localized: "hücresel veride otomatik indir"),
                        key: "auto_download_cellular",
                        defaultValue: false
                    )
                }
                
                // Cache Download
                storageSection(title: String(localized: "onbellek indir")) {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("tum fotograflari indir")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))

                                Text("sunucudaki tum gorselleri onbellege kaydeder")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.25))
                            }

                            Spacer()

                            Button {
                                downloadAllPhotos()
                            } label: {
                                if isDownloading {
                                    ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.8)
                                } else {
                                    Text("indir")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                            }
                            .disabled(isDownloading)
                        }

                        if isDownloading {
                            VStack(spacing: 6) {
                                ProgressView(value: downloadProgress)
                                    .tint(.white)

                                Text("\(downloadDone)/\(downloadTotal) gorsel")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Info
                Text("onbelleği temizlemek uygulama boyutunu kucultur. gorseller tekrar yuklenecektir.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("depolama ve veri")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await calculateCacheSize()
        }
        .alert("önbelleği temizle", isPresented: $showClearAlert) {
            Button("iptal", role: .cancel) {}
            Button("temizle", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("tüm önbelleğe alınmış görseller silinecek. görseller tekrar indirilecektir.")
        }
        .overlay {
            if clearSuccess {
                VStack {
                    Label("onbellek temizlendi", systemImage: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { clearSuccess = false }
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func storageSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
    
    private func autoDownloadRow(label: String, key: String, defaultValue: Bool) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue },
                set: { UserDefaults.standard.set($0, forKey: key) }
            ))
            .tint(.white.opacity(0.5))
            .labelsHidden()
        }
        .padding(.vertical, 6)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 0.5)
    }
    
    // MARK: - Actions
    
    private func calculateCacheSize() async {
        let urlCacheSize = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage
        
        var appGroupSize: Int64 = 0
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) {
            let cacheFile = containerURL.appendingPathComponent("history_cache.json")
            let imageFile = containerURL.appendingPathComponent("latest_widget_image.jpg")
            appGroupSize += (try? FileManager.default.attributesOfItem(atPath: cacheFile.path)[.size] as? Int64) ?? 0
            appGroupSize += (try? FileManager.default.attributesOfItem(atPath: imageFile.path)[.size] as? Int64) ?? 0
        }
        
        let totalBytes = Int64(urlCacheSize) + appGroupSize
        cacheSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    private func downloadAllPhotos() {
        isDownloading = true
        downloadDone = 0

        // Collect all unique image URLs from local strips
        var urls: [String] = []
        for strip in localStrips {
            urls.append(strip.imageUrl)
            if let thumb = strip.thumbnailUrl { urls.append(thumb) }
        }
        downloadTotal = urls.count

        Task {
            // Download in batches of 6 for controlled concurrency
            let batchSize = 6
            for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, urls.count)
                let batch = Array(urls[batchStart..<batchEnd])
                await withTaskGroup(of: Void.self) { group in
                    for urlString in batch {
                        group.addTask {
                            guard let url = URL(string: urlString) else { return }
                            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                            _ = try? await URLSession.shared.data(for: request)
                        }
                    }
                }
                await MainActor.run {
                    downloadDone = batchEnd
                    downloadProgress = Double(downloadDone) / Double(downloadTotal)
                }
            }
            await calculateCacheSize()
            isDownloading = false
            downloadProgress = 0
            HapticsManager.playNotification(type: .success)
            withAnimation { downloadSuccess = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { downloadSuccess = false }
        }
    }

    private func clearCache() {
        isClearing = true
        Task {
            // Clear URLCache
            URLCache.shared.removeAllCachedResponses()
            
            // Clear App Group cache files
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) {
                let cacheFile = containerURL.appendingPathComponent("history_cache.json")
                try? FileManager.default.removeItem(at: cacheFile)
            }
            
            await calculateCacheSize()
            isClearing = false
            HapticsManager.playNotification(type: .success)
            withAnimation { clearSuccess = true }
        }
    }
}
