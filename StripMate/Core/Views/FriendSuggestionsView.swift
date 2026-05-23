import SwiftUI

/// Sheet shown to users with fewer than 3 friends — surfaces contacts who are
/// already on anlık. and offers a one-tap "ekle" button. Shown at most once per
/// 7 days so it doesn't become noise for users who explicitly want to keep
/// their circle small.
struct FriendSuggestionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ContactSyncViewModel()
    @State private var hasStarted = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if viewModel.isSyncing {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text(String(localized: "rehberde anlık. kullananlar aranıyor…"))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 16)
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        errorState(error)
                    } else if viewModel.service.matchedContacts.isEmpty {
                        emptyState
                    } else {
                        suggestionList
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "kapat")) {
                        markShown()
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            viewModel.startSync()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Text(String(localized: "rehberinde anlık.'ta olanlar"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(String(localized: "ilk birkaç arkadaşı eklemek anlık.'ı seninle birlikte canlı tutar."))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.service.matchedContacts) { contact in
                    suggestionRow(contact)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func suggestionRow(_ contact: ContactSyncService.MatchedContact) -> some View {
        let alreadyRequested = viewModel.sentRequestIds.contains(contact.id)
        let isSending = viewModel.sendingRequestFor == contact.id

        return HStack(spacing: 12) {
            // Avatar
            Group {
                if !contact.avatarUrl.isEmpty, let url = URL(string: contact.avatarUrl) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder(name: contact.displayName.isEmpty ? contact.username : contact.displayName)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder(name: contact.displayName.isEmpty ? contact.username : contact.displayName)
                        .frame(width: 44, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName.isEmpty ? contact.username : contact.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !contact.username.isEmpty && !contact.displayName.isEmpty {
                    Text("@\(contact.username)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.sendFriendRequest(to: contact.id) }
                HapticsManager.playImpact(style: .light)
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(.black)
                    } else if alreadyRequested {
                        Text(String(localized: "istek gitti"))
                    } else {
                        Text(String(localized: "ekle"))
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 78)
                .padding(.vertical, 8)
                .background(alreadyRequested ? Color.white.opacity(0.12) : Color.white)
                .foregroundStyle(alreadyRequested ? .white.opacity(0.5) : .black)
                .clipShape(Capsule())
            }
            .disabled(alreadyRequested || isSending)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func avatarPlaceholder(name: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .overlay(
                Text(String((name.isEmpty ? "?" : name).prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.4))
            Text(String(localized: "rehberinde anlık. kullanan kimseyi bulamadık"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text(String(localized: "davet kodunu paylaşarak arkadaşlarını ekleyebilirsin"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Persistence

    private func markShown() {
        UserDefaults.standard.set(Date(), forKey: "friendSuggestions.lastShownAt")
    }
}

// MARK: - Trigger helper

enum FriendSuggestionsTrigger {
    /// True when the user has fewer than 3 accepted friends AND the suggestion
    /// sheet hasn't been shown in the last 7 days. Caller should still gate on
    /// "user is past friend gate" so we don't double-stack with onboarding.
    static func shouldShow(friendCount: Int) -> Bool {
        guard friendCount < 3 else { return false }
        let lastShown = UserDefaults.standard.object(forKey: "friendSuggestions.lastShownAt") as? Date
        guard let lastShown else { return true }
        return Date().timeIntervalSince(lastShown) > 7 * 24 * 3600
    }
}
