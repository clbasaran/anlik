import SwiftUI

// MARK: - Edit Profile View

struct EditProfileView: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedDate: Date = Date()
    @State private var favoriteSong: String = ""
    @State private var selectedZodiac: String = ""
    @State private var personalityEmojis: [String] = []
    @State private var showEmojiPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    // Spotify search
    @State private var showSpotifySearch = false
    @State private var spotifyQuery = ""
    @State private var spotifyResults: [SpotifyTrack] = []
    @State private var isSearchingSpotify = false

    private let maxBioLength = 60
    private let maxSongLength = 100

    private let zodiacSigns: [(key: String, name: String, icon: String)] = [
        ("aries", "Koc", "arrow.up.right"),
        ("taurus", "Boga", "circle.fill"),
        ("gemini", "Ikizler", "person.2"),
        ("cancer", "Yengec", "moon.fill"),
        ("leo", "Aslan", "sun.max.fill"),
        ("virgo", "Basak", "leaf.fill"),
        ("libra", "Terazi", "scale.3d"),
        ("scorpio", "Akrep", "bolt.fill"),
        ("sagittarius", "Yay", "location.north.fill"),
        ("capricorn", "Oglak", "mountain.2.fill"),
        ("aquarius", "Kova", "drop.fill"),
        ("pisces", "Balik", "water.waves")
    ]

    private let emojiOptions = ["face.smiling", "eyeglasses", "party.popper.fill", "theatermasks.fill", "heart.fill", "heart.circle.fill", "moon.zzz.fill", "brain.head.profile.fill", "face.dashed", "sparkles", "star.fill", "hand.wave.fill", "questionmark.circle", "arrow.uturn.down.circle", "wind", "tornado", "face.smiling.inverse", "lasso", "ghost.fill", "skull.fill", "cpu", "ant.fill", "leaf.fill", "camera.fill", "bolt.fill", "rainbow", "music.note", "gamecontroller.fill", "basketball.fill", "soccerball", "paintpalette.fill", "books.vertical.fill", "cup.and.saucer.fill", "popcorn.fill", "water.waves", "mountain.2.fill", "moon.fill", "star.circle.fill", "wand.and.stars", "heart.text.clipboard.fill", "heart.square.fill", "heart.rectangle.fill"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Display Name
                fieldSection(title: String(localized: "görünen ad")) {
                    TextField("", text: $displayName, prompt: Text(String(localized: "adın")).foregroundColor(.white.opacity(0.2)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                        .accessibilityLabel(String(localized: "Görünen ad"))
                        .accessibilityHint(String(localized: "Profilde görünen adını düzenle"))
                }
                
                // Username
                fieldSection(title: String(localized: "kullanıcı adı")) {
                    HStack {
                        Text("@")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                        
                        TextField("", text: $username, prompt: Text(String(localized: "kullanıcı adı")).foregroundColor(.white.opacity(0.2)))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .accessibilityLabel(String(localized: "Kullanıcı adı"))
                    .accessibilityHint(String(localized: "@ ile başlayan benzersiz kullanıcı adını düzenle"))
                }
                
                // Bio
                fieldSection(title: String(localized: "biyografi")) {
                    VStack(alignment: .trailing, spacing: 6) {
                        TextField("", text: $bio, prompt: Text(String(localized: "kendinden kısaca bahset...")).foregroundColor(.white.opacity(0.2)), axis: .vertical)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2...3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > maxBioLength {
                                    bio = String(newValue.prefix(maxBioLength))
                                }
                            }
                        
                        Text("\(bio.count)/\(maxBioLength)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))
                            .padding(.trailing, 4)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Biyografi, \(bio.count) / \(maxBioLength) karakter"))
                }
                
                // Favorite Song (Spotify search)
                fieldSection(title: String(localized: "favori şarkı")) {
                    Button {
                        HapticsManager.playImpact(style: .light)
                        showSpotifySearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.6))
                            if favoriteSong.isEmpty {
                                Text(String(localized: "Spotify'dan şarkı seç"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                            } else {
                                Text(favoriteSong)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                // Zodiac Sign
                fieldSection(title: String(localized: "burç")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(zodiacSigns, id: \.key) { zodiac in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedZodiac = selectedZodiac == zodiac.key ? "" : zodiac.key
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: zodiac.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                        Text(zodiac.name)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(selectedZodiac == zodiac.key ? 0.9 : 0.4))
                                    }
                                    .frame(width: 56, height: 56)
                                    .background(selectedZodiac == zodiac.key ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(selectedZodiac == zodiac.key ? Color.white.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Personality Emojis
                fieldSection(title: String(localized: "kişilik emojileri")) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(0..<5) { index in
                                Button {
                                    if index < personalityEmojis.count {
                                        personalityEmojis.remove(at: index)
                                    } else {
                                        showEmojiPicker = true
                                    }
                                } label: {
                                    ZStack {
                                        if index < personalityEmojis.count {
                                            Image(systemName: personalityEmojis[index])
                                                .font(.system(size: 24))
                                                .foregroundStyle(.white)
                                        } else {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.25))
                                        }
                                    }
                                    .frame(width: 52, height: 52)
                                    .background(index < personalityEmojis.count ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !personalityEmojis.isEmpty {
                            Text(String(localized: "silmek için emojiye dokun"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                }

                // Birthday
                fieldSection(title: String(localized: "doğum tarihi")) {
                    DatePicker("", selection: $selectedDate, in: ...(Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                        .accessibilityLabel(String(localized: "Doğum tarihi"))
                }
                
                // Email (read-only)
                if let email = profile.email {
                    fieldSection(title: String(localized: "e-posta")) {
                        HStack {
                            Text(email)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                
                // Invite Code (read-only)
                fieldSection(title: String(localized: "davet kodu")) {
                    HStack {
                        Text(profile.inviteCode)
                            .font(.system(size: 16, design: .monospaced).weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = profile.inviteCode
                            HapticsManager.playNotification(type: .success)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                // Save Button
                Button {
                    saveProfile()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        }
                        Text(String(localized: "kaydet"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(String(localized: "profili düzenle"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            displayName = profile.displayName ?? ""
            username = profile.username ?? ""
            bio = profile.bio ?? ""
            favoriteSong = profile.favoriteSong ?? ""
            selectedZodiac = profile.zodiacSign ?? ""
            personalityEmojis = profile.personalityEmojis ?? []
            selectedDate = profile.dateOfBirth ?? Date()
        }
        .overlay {
            if showSuccess {
                VStack {
                    Label(String(localized: "kaydedildi"), systemImage: "checkmark")
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
                        withAnimation { showSuccess = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            emojiPickerSheet
        }
        .sheet(isPresented: $showSpotifySearch) {
            spotifySearchSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
    }

    // MARK: - Spotify Search Sheet

    private var spotifySearchSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    TextField(String(localized: "şarkı ara..."), text: $spotifyQuery)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { searchSpotify() }

                    if isSearchingSpotify {
                        ProgressView().tint(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: spotifyQuery) { _, newValue in
                    guard newValue.count >= 2 else {
                        spotifyResults = []
                        return
                    }
                    // Debounced search
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard spotifyQuery == newValue else { return }
                        searchSpotify()
                    }
                }

                // Results
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(spotifyResults) { track in
                            Button {
                                HapticsManager.playImpact(style: .light)
                                favoriteSong = "\(track.name) — \(track.artist)"
                                showSpotifySearch = false
                            } label: {
                                HStack(spacing: 14) {
                                    // Album art
                                    if let artUrl = track.albumArtUrl, let url = URL(string: artUrl) {
                                        CachedAsyncImage(url: url) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.06))
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Image(systemName: "music.note")
                                                    .foregroundStyle(.white.opacity(0.3))
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.4))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color.black)
            .navigationTitle("Spotify'dan Şarkı Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Kapat")) { showSpotifySearch = false }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func searchSpotify() {
        guard !spotifyQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchingSpotify = true
        Task {
            spotifyResults = await SpotifySearchService.search(query: spotifyQuery)
            isSearchingSpotify = false
        }
    }

    private var emojiPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(emojiOptions, id: \.self) { iconName in
                        Button {
                            if personalityEmojis.count < 5 && !personalityEmojis.contains(iconName) {
                                personalityEmojis.append(iconName)
                            }
                            if personalityEmojis.count >= 5 {
                                showEmojiPicker = false
                            }
                        } label: {
                            Image(systemName: iconName)
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(personalityEmojis.contains(iconName) ? Color.white.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(personalityEmojis.contains(iconName))
                        .opacity(personalityEmojis.contains(iconName) ? 0.4 : 1)
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "ikon sec"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "tamam")) {
                        showEmojiPicker = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func fieldSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)
            
            content()
        }
    }
    
    private func saveProfile() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
                let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
                let trimmedBio = bio.trimmingCharacters(in: .whitespaces)
                
                guard !trimmedName.isEmpty else {
                    errorMessage = String(localized: "görünen ad boş olamaz.")
                    isSaving = false
                    return
                }
                
                let trimmedSong = favoriteSong.trimmingCharacters(in: .whitespaces)

                // Save to Firestore
                try await AuthService.shared.updateProfile(
                    displayName: trimmedName,
                    username: trimmedUsername.isEmpty ? nil : trimmedUsername,
                    bio: trimmedBio.isEmpty ? nil : trimmedBio,
                    dateOfBirth: selectedDate,
                    favoriteSong: trimmedSong.isEmpty ? nil : trimmedSong,
                    zodiacSign: selectedZodiac.isEmpty ? nil : selectedZodiac,
                    personalityEmojis: personalityEmojis.isEmpty ? nil : personalityEmojis
                )
                
                HapticsManager.playNotification(type: .success)
                withAnimation { showSuccess = true }
            } catch {
                errorMessage = error.localizedDescription
                HapticsManager.playNotification(type: .error)
            }
            isSaving = false
        }
    }
}
