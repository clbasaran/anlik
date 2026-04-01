import SwiftUI

struct ContactSyncView: View {
    @State private var vm = ContactSyncViewModel()
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredMatched: [ContactSyncService.MatchedContact] {
        if searchText.isEmpty { return vm.service.matchedContacts }
        let q = searchText.lowercased()
        return vm.service.matchedContacts.filter {
            $0.displayName.lowercased().contains(q) || $0.username.lowercased().contains(q)
        }
    }

    private var filteredUnmatched: [ContactSyncService.UnmatchedContact] {
        if searchText.isEmpty { return vm.service.unmatchedContacts }
        let q = searchText.lowercased()
        return vm.service.unmatchedContacts.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.service.state {
                case .idle:
                    idleView
                case .requestingPermission, .loading:
                    loadingView
                case .done:
                    resultsView
                case .error(let msg):
                    errorView(msg)
                }
            }
            .navigationTitle("Rehberden Bul")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Rehberindeki Arkadaşlarını Bul")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Telefon numaraları şifreli şekilde kontrol edilir.\nHiçbiri sunucuya kaydedilmez.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                vm.startSync()
            } label: {
                Text("Rehbere Erişim İzni Ver")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Rehber taranıyor...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        List {
            if !filteredMatched.isEmpty {
                Section {
                    ForEach(filteredMatched) { contact in
                        matchedRow(contact)
                    }
                } header: {
                    Label("anlık.'ta Olanlar (\(vm.service.matchedContacts.count))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if !filteredUnmatched.isEmpty {
                Section {
                    ForEach(filteredUnmatched) { contact in
                        unmatchedRow(contact)
                    }
                } header: {
                    Label("Davet Et (\(vm.service.unmatchedContacts.count))", systemImage: "envelope.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if filteredMatched.isEmpty && filteredUnmatched.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if vm.service.matchedContacts.isEmpty && vm.service.unmatchedContacts.isEmpty {
                ContentUnavailableView(
                    "Kimse Bulunamadı",
                    systemImage: "person.slash",
                    description: Text("Rehberindeki kişiler henüz anlık.'ta değil.")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Kişi ara...")
    }

    @ViewBuilder
    private func matchedRow(_ contact: ContactSyncService.MatchedContact) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: contact.avatarUrl)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.white.opacity(0.15))
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.subheadline.bold())
                Text("@\(contact.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if vm.sentRequestIds.contains(contact.id) {
                Label("Gönderildi", systemImage: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Button {
                    Task { await vm.sendFriendRequest(to: contact.id) }
                } label: {
                    if vm.sendingRequestFor == contact.id {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text("Ekle")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .disabled(vm.sendingRequestFor != nil)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func unmatchedRow(_ contact: ContactSyncService.UnmatchedContact) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(contact.name.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(.gray)
                )

            Text(contact.name)
                .font(.subheadline)

            Spacer()

            Button {
                vm.sendSMSInvite(to: contact)
            } label: {
                Text("Davet Et")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule().stroke(.white, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Tekrar Dene") { vm.startSync() }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            Spacer()
        }
        .padding()
    }
}
