import SwiftUI

// MARK: - Storage Settings View

struct StorageSettingsView: View {
    @State private var cacheSize: String = "hesaplanıyor..."
    @State private var isClearing = false
    @State private var showClearAlert = false
    @State private var clearSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cache Info
                storageSection(title: "önbellek") {
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
                storageSection(title: "veri kullanımı") {
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
                storageSection(title: "otomatik indirme") {
                    autoDownloadRow(
                        label: "wi-fi'da otomatik indir",
                        key: "auto_download_wifi",
                        defaultValue: true
                    )
                    divider
                    autoDownloadRow(
                        label: "hücresel veride otomatik indir",
                        key: "auto_download_cellular",
                        defaultValue: false
                    )
                }
                
                // Info
                Text("önbelleği temizlemek uygulama boyutunu küçültür. görseller tekrar yüklenecektir.")
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
                    Text("✓ önbellek temizlendi")
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
