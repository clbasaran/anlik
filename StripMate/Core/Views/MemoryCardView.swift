import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// A compact card shown in the HistoryView header when photos from exactly
/// one year ago today exist. Tapping it opens a full memory detail view.
struct MemoryCardView: View {
    let strips: [Strip]

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let firstStrip = strips.first,
               let url = URL(string: firstStrip.smallThumbnailUrl ?? firstStrip.thumbnailUrl ?? firstStrip.imageUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                    Text(String(localized: "ge\u{00E7}en y\u{0131}l bug\u{00FC}n"))
                        .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                        .foregroundStyle(.white)
                }

                Text(String(localized: "\(strips.count) an"))
                    .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Full-screen view showing "today last year" memory photos.
struct MemoryDetailView: View {
    let strips: [Strip]
    @Environment(\.dismiss) private var dismiss
    @State private var resharingStrip: Strip?
    @State private var resharePickerSelection: Set<String> = []
    @State private var availableFriends: [FriendStatus] = []
    @State private var resharingInFlight = false
    /// duygusal-11: reshare success is a quiet monochrome toast, not an alert.
    @State private var showReshareToast = false
    @State private var resharingComment: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    CircleIconButton(icon: "xmark", size: 40, iconSize: 16, accessibilityLabel: "kapat") {
                        dismiss()
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(Brand.scaledFont(size: 16, relativeTo: .body))
                            Text(String(localized: "ge\u{00E7}en y\u{0131}l bug\u{00FC}n"))
                                .font(Brand.scaledFont(size: 18, weight: .bold, relativeTo: .title3))
                                .foregroundStyle(.white)
                        }
                        if let first = strips.first {
                            Text(first.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Spacer for symmetry
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Photos grid
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(strips, id: \.id) { strip in
                            let imageUrl = URL(string: strip.thumbnailUrl ?? strip.imageUrl)
                            CachedAsyncImage(url: imageUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 350)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.white.opacity(0.04))
                                    .frame(height: 350)
                                    .overlay {
                                        ProgressView().tint(.white.opacity(0.2))
                                    }
                            }
                            .overlay(alignment: .bottomLeading) {
                                HStack(spacing: 6) {
                                    if let city = strip.cityName {
                                        Text(city)
                                            .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                                            .foregroundStyle(.white)
                                    }
                                    Text(strip.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Button {
                                    HapticsManager.playImpact(style: .light)
                                    resharingComment = ""
                                    resharePickerSelection = []
                                    resharingStrip = strip
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.right")
                                            .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                                        Text(String(localized: "yeniden paylaş"))
                                            .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            // Load friends once for the picker — reuses the same set the camera VM uses.
            if availableFriends.isEmpty {
                availableFriends = (try? await DependencyContainer.shared.friendRepository.fetchFriends())?
                    .filter { !$0.isPending } ?? []
            }
        }
        .sheet(item: $resharingStrip) { strip in
            FriendSelectionSheet(
                friends: availableFriends,
                selectedIds: $resharePickerSelection,
                commentText: $resharingComment,
                onSend: {
                    Task { await reshare(strip: strip) }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .overlay {
            if resharingInFlight {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.4)
            }
        }
        // duygusal-11: the most sentimental action in the app deserves better
        // than a system alert — a small monochrome moment instead.
        .overlay(alignment: .top) {
            if showReshareToast {
                reshareToast
            }
        }
    }

    // MARK: - Reshare Toast (duygusal-11)

    private var reshareToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperplane.fill")
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
            Text(String(localized: "anı yeniden yola çıktı."))
                .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(Brand.Animations.fade) { showReshareToast = false }
            }
        }
    }

    /// Re-shares an existing memory strip by writing a fresh `strips` document
    /// that points to the same image/video URL. The original Storage object
    /// stays in place — we just create a new social envelope around it.
    @MainActor
    private func reshare(strip: Strip) async {
        guard !resharePickerSelection.isEmpty,
              let uid = Auth.auth().currentUser?.uid else { return }
        resharingInFlight = true
        defer { resharingInFlight = false }

        let receivers = Array(resharePickerSelection)
        // Sender always lands in receiverIds so the strip lands on their own
        // history feed too — same shape strips have today.
        let finalReceivers = receivers.contains(uid) ? receivers : receivers + [uid]
        let newId = "\(uid)_\(UUID().uuidString)"

        var data: [String: Any] = [
            "id": newId,
            "senderId": uid,
            "receiverIds": finalReceivers,
            "imageUrl": strip.imageUrl,
            "timestamp": FieldValue.serverTimestamp(),
            "resharedFrom": strip.id
        ]
        if let thumb = strip.thumbnailUrl { data["thumbnailUrl"] = thumb }
        if let smallThumb = strip.smallThumbnailUrl { data["smallThumbnailUrl"] = smallThumb }
        if let videoUrl = strip.videoUrl { data["videoUrl"] = videoUrl }
        if let dur = strip.videoDuration { data["videoDuration"] = dur }
        if let lat = strip.latitude { data["latitude"] = lat }
        if let lon = strip.longitude { data["longitude"] = lon }
        if let city = strip.cityName, !city.isEmpty { data["cityName"] = city }
        let comment = resharingComment.trimmingCharacters(in: .whitespacesAndNewlines)
        // The text caption rides on the strip-chat side, not the strip itself,
        // so pre-seed a chat message in the sender→sender channel if provided.
        do {
            try await Firestore.firestore().collection("strips").document(newId).setData(data)
            if !comment.isEmpty, let firstReceiver = receivers.first {
                let msgId = UUID().uuidString
                try? await Firestore.firestore()
                    .collection("strips").document(newId)
                    .collection("chats").document(firstReceiver)
                    .collection("messages").document(msgId)
                    .setData([
                        "id": msgId,
                        "photoId": newId,
                        "senderId": uid,
                        "text": comment,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
            }
            HapticsManager.playNotification(type: .success)
            resharingStrip = nil
            withAnimation(reduceMotion ? Brand.Animations.fade : Brand.Animations.snap) {
                showReshareToast = true
            }
        } catch {
            HapticsManager.playNotification(type: .error)
        }
    }
}
