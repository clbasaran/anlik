import SwiftUI

struct SupportChatView: View {
    @State private var viewModel = SupportChatViewModel()
    @AppStorage("show_support_chat_note") private var showWarmIntro = true

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.messages.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 20) {
                                if showWarmIntro {
                                    WarmNoteCard(
                                        eyebrow: String(localized: "canlı destek"),
                                        title: String(localized: "burada gerçekten birileri var"),
                                        message: String(localized: "takıldığın bir yer varsa yaz. kısa mesajlar da olur, uzun uzun anlatman da. her şeyi okuyup elimizden geldiğince hızlı dönüyoruz."),
                                        dismissLabel: String(localized: "tamam"),
                                        onDismiss: {
                                            withAnimation(Brand.Animations.fade) {
                                                showWarmIntro = false
                                            }
                                        }
                                    )
                                }

                                Text(String(localized: "merhaba!"))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(String(localized: "ister sorun bildir, ister fikir bırak, istersen sadece selam ver."))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)

                                Text(String(localized: "— celal, anlık. geliştiricisi"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                            .padding(.top, 60)
                        }

                        ForEach(viewModel.messages) { message in
                            let isMe = !message.isAdmin
                            HStack {
                                if isMe { Spacer() }

                                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                                    if message.isAdmin {
                                        Text(String(localized: "anlık. ekibi"))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }

                                    Text(message.text)
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundColor(isMe ? .black : .white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(isMe ? Color.white : Color(white: 0.25))
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }

                                if !isMe { Spacer() }
                            }
                            .padding(.horizontal, 16)
                            .id(message.id)
                        }

                        Color.clear.frame(height: 1).id("support_bottom")
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    if newCount > oldCount {
                        withAnimation(Brand.Animations.fade) {
                            proxy.scrollTo("support_bottom", anchor: .bottom)
                        }
                    }
                }
            }

            // MARK: - Input Bar
            inputBar
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(String(localized: "canlı destek"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            viewModel.listenToMessages()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(String(localized: "mesaj yaz..."), text: $viewModel.inputText, axis: .vertical)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    Task { await viewModel.sendMessage() }
                }

            if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .white)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(Brand.Animations.fadeFast, value: viewModel.inputText.isEmpty)
    }
}
