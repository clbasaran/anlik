import SwiftUI

struct SupportChatView: View {
    @State private var viewModel = SupportChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.messages.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 20) {
                                Text("merhaba!")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)

                                VStack(spacing: 10) {
                                    Text("anlık. henüz çok yeni bir uygulama ve bunun farkındayız.")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))

                                    Text("bir sorunla karşılaştıysan, aklına bir fikir geldiyse veya sadece merhaba demek istiyorsan yaz bize. her mesajı bizzat okuyoruz.")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .multilineTextAlignment(.center)

                                Text("— celal, anlık. geliştiricisi")
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
                                        Text("Admin")
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
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("support_bottom", anchor: .bottom)
                        }
                    }
                }
            }

            // MARK: - Input Bar
            inputBar
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("canlı destek")
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
            TextField("mesaj yaz...", text: $viewModel.inputText, axis: .vertical)
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
        .animation(.easeInOut(duration: 0.15), value: viewModel.inputText.isEmpty)
    }
}
