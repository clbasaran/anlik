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
                        .font(.system(size: 14))
                    Text(String(localized: "ge\u{00E7}en y\u{0131}l bug\u{00FC}n"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(String(localized: "\(strips.count) an"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
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
    @State private var rashareSuccess = false
    @State private var resharingComment: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                            Text(String(localized: "ge\u{00E7}en y\u{0131}l bug\u{00FC}n"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        if let first = strips.first {
                            Text(first.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Spacer for symmetry
                    Color.clear.frame(width: 40, height: 40)
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
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Text(strip.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 12, weight: .medium))
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
                                            .font(.system(size: 12, weight: .bold))
                                        Text(String(localized: "yeniden paylaş"))
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.black)
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
        .alert(String(localized: "tekrar paylaşıldı"), isPresented: $rashareSuccess) {
            Button("tamam", role: .cancel) {}
        } message: {
            Text(String(localized: "an gönderildi."))
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
            rashareSuccess = true
        } catch {
            HapticsManager.playNotification(type: .error)
        }
    }
}
