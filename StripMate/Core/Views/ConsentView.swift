import SwiftUI

/// Mandatory consent screen shown before account creation.
/// User must accept all legal documents to proceed.
/// Consent is recorded in Firestore with timestamp, version, device info.
struct ConsentView: View {
    let onAcceptAll: () -> Void
    
    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedKVKK = false
    @State private var acceptedEULA = false
    @State private var selectedDocument: LegalDocument?
    
    private var allAccepted: Bool {
        acceptedTerms && acceptedPrivacy && acceptedKVKK && acceptedEULA
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(String(localized: "yasal belgeler"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text(String(localized: "devam etmek için aşağıdaki belgeleri okumalı ve onaylamalısın."))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Document list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        consentRow(
                            document: .termsOfService,
                            isAccepted: $acceptedTerms
                        )
                        
                        consentRow(
                            document: .privacyPolicy,
                            isAccepted: $acceptedPrivacy
                        )
                        
                        consentRow(
                            document: .kvkk,
                            isAccepted: $acceptedKVKK
                        )
                        
                        consentRow(
                            document: .eula,
                            isAccepted: $acceptedEULA
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // Info note
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text(String(localized: "onayınız Firestore'da güvenli şekilde kaydedilir ve istenildiğinde erişilebilir."))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
                
                Spacer()
                
                // Accept All + Continue
                VStack(spacing: 14) {
                    // Select all toggle
                    Button {
                        HapticsManager.playImpact(style: .light)
                        let newValue = !allAccepted
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            acceptedTerms = newValue
                            acceptedPrivacy = newValue
                            acceptedKVKK = newValue
                            acceptedEULA = newValue
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(allAccepted ? Color.white : Color.white.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                
                                if allAccepted {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.black)
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allAccepted)
                            
                            Text(String(localized: "tümünü okudum ve kabul ediyorum"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    // Continue button
                    Button {
                        HapticsManager.playNotification(type: .success)
                        onAcceptAll()
                    } label: {
                        Text(String(localized: "devam et"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(allAccepted ? Color.white : Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!allAccepted)
                    .animation(.easeInOut(duration: 0.2), value: allAccepted)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $selectedDocument) { doc in
            LegalDocumentView(document: doc)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
    }
    
    // MARK: - Consent Row
    
    private func consentRow(document: LegalDocument, isAccepted: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            // Checkbox
            Button {
                HapticsManager.playSelection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isAccepted.wrappedValue.toggle()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isAccepted.wrappedValue ? Color.white : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    
                    if isAccepted.wrappedValue {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAccepted.wrappedValue)
            }
            
            // Document info
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(String(localized: "oku ve onayla"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            
            Spacer()
            
            // Read button
            Button {
                selectedDocument = document
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: document.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "oku"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isAccepted.wrappedValue ? Color.white.opacity(0.15) : Color.white.opacity(0.06),
                    lineWidth: 0.5
                )
        )
    }
}
