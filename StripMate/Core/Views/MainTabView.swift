import SwiftUI
import FirebaseAuth
import StoreKit

// MARK: - Tab Definition

public enum TabItem: Int, CaseIterable {
    case friends = 0
    case camera = 1
    case history = 2

    var iconName: String {
        switch self {
        case .friends: return "person.2.fill"
        case .camera: return "camera.fill"
        case .history: return "square.grid.2x2.fill"
        }
    }
    
    var accessibilityName: String {
        switch self {
        case .friends: return String(localized: "Arkadaşlar")
        case .camera: return String(localized: "Kamera")
        case .history: return String(localized: "Geçmiş")
        }
    }
}

@MainActor
@Observable
public final class TabBarState {
    public static let shared = TabBarState()
    public var isHidden = false
    public var selectedTab: TabItem = .camera {
        didSet {
            UserDefaults.standard.set(selectedTab.rawValue, forKey: "lastSelectedTab")
        }
    }
    public var isSendingPhoto = false
    /// When true, tab swipe gesture is disabled (e.g. map is active)
    public var isSwipeDisabled = false

    private init() {
        // Her zaman kamera tab'ında başla — camera-first UX
    }
}

/// Tracks which DM conversation is currently open so we can suppress notifications for it.
@MainActor
@Observable
public final class ActiveChatState {
    public static let shared = ActiveChatState()
    /// The partner user ID of the currently open DM screen, or nil if no DM is open.
    public var activeDMPartnerId: String?
}

// MARK: - Root View

public struct MainTabView: View {
    @Environment(\.requestReview) private var requestReview
    @State private var isInPreviewMode = false
    @Binding var pendingDeepLink: URL?
    
    private var selectedTab: TabItem {
        get { TabBarState.shared.selectedTab }
        nonmutating set { TabBarState.shared.selectedTab = newValue }
    }
    
    // Deep link navigation state
    @State private var deepLinkStripPhoto: PhotoMetadata?
    @State private var deepLinkReceiverId: String?
    @State private var deepLinkDMPartner: UserProfile?
    
    // Swipe gesture state
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally = false
    
    // Global error toast
    @State private var globalErrorMessage: String?
    
    // Tab badge counts
    @State private var friendsPendingCount: Int = 0
    @State private var notificationUnreadCount: Int = 0

    public init(pendingDeepLink: Binding<URL?> = .constant(nil)) {
        self._pendingDeepLink = pendingDeepLink
    }

    public var body: some View {
        GeometryReader { geometry in
            Color.clear
                .background(Color.black.ignoresSafeArea())
                .overlay(
                    // ── Full-bleed content layer with swipe ──
                    ZStack {
                        ForEach(TabItem.allCases, id: \.self) { tab in
                            Group {
                                switch tab {
                                case .friends:
                                    FriendsListView()
                                case .camera:
                                    MainCameraView(isInPreviewMode: $isInPreviewMode)
                                case .history:
                                    HistoryView()
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(tab.rawValue - selectedTab.rawValue) * geometry.size.width + dragOffset)
                        }
                    }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .global)
                        .onChanged { value in
                            guard !isInPreviewMode && !TabBarState.shared.isSwipeDisabled else { return }
                            
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            
                            // Decide direction on first significant movement
                            if !isDraggingHorizontally {
                                guard horizontal > vertical * 1.2 && horizontal > 10 else { return }
                                isDraggingHorizontally = true
                            }
                            
                            guard isDraggingHorizontally else { return }
                            
                            // Resist at edges
                            if (selectedTab == .friends && value.translation.width > 0) ||
                               (selectedTab == .history && value.translation.width < 0) {
                                dragOffset = value.translation.width * 0.2
                            } else {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            defer { isDraggingHorizontally = false }
                            guard !isInPreviewMode && !TabBarState.shared.isSwipeDisabled else {
                                dragOffset = 0
                                return
                            }
                            guard isDraggingHorizontally else {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    dragOffset = 0
                                }
                                return
                            }
                            
                            let threshold: CGFloat = geometry.size.width * 0.2
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                if (value.translation.width + velocity) < -threshold,
                                   let next = TabItem(rawValue: selectedTab.rawValue + 1) {
                                    selectedTab = next
                                    HapticsManager.playSelection()
                                } else if (value.translation.width + velocity) > threshold,
                                          let prev = TabItem(rawValue: selectedTab.rawValue - 1) {
                                    selectedTab = prev
                                    HapticsManager.playSelection()
                                }
                                dragOffset = 0
                            }
                        }
                )
                .overlay(
                    // ── Floating Tab Bar ──
                    VStack {
                        Spacer()
                        if !isInPreviewMode && !TabBarState.shared.isHidden {
                            floatingTabBar
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                )
                .overlay(alignment: .top) {
                    // ── Subtle breathing upload line ──
                    if TabBarState.shared.isSendingPhoto {
                        BreathingUploadLine()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: TabBarState.shared.isSendingPhoto)
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: selectedTab)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isInPreviewMode)
        .preferredColorScheme(.dark)
        .task {
            // Fetch badge counts
            friendsPendingCount = await DependencyContainer.shared.friendRepository.fetchPendingCount()
        }
        .onChange(of: selectedTab) { _, _ in
            // Refresh badge counts on tab switch
            Task {
                friendsPendingCount = await DependencyContainer.shared.friendRepository.fetchPendingCount()
            }
        }
        .onAppear {
            if let url = pendingDeepLink {
                handle(url)
                pendingDeepLink = nil
            }
            // Track app opens for review milestone logic
            ReviewPromptService.recordAppOpen()
        }
        // Show App Store review dialog when ReviewPromptService hits a milestone
        .onReceive(NotificationCenter.default.publisher(for: .requestAppReview)) { _ in
            requestReview()
        }
        .onChange(of: pendingDeepLink) { _, newUrl in
            if let url = newUrl {
                handle(url)
                pendingDeepLink = nil
            }
        }
        .sheet(item: $deepLinkStripPhoto) { photo in
            let isMine = photo.senderId == Auth.auth().currentUser?.uid
            PhotoDetailView(photo: photo, isSentByMe: isMine, preSelectedReceiverId: deepLinkReceiverId)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(.black)
        }
        .sheet(item: $deepLinkDMPartner) { partner in
            NavigationStack {
                DirectMessageView(partner: partner)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
            .presentationBackground(.black)
        }
        .errorToast($globalErrorMessage)
        .environment(\.globalError, $globalErrorMessage)
    }
    
    private func handle(_ url: URL) {
        guard url.scheme == "stripmate" else { return }
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch host {
        case "camera":
            selectedTab = .camera
            isInPreviewMode = false
            
        case "chat":
            // stripmate://chat/{stripId} or stripmate://chat/{stripId}/{receiverId}
            if let stripId = pathComponents.first, !stripId.isEmpty {
                let rcvId = pathComponents.count > 1 ? pathComponents[1] : nil
                Task {
                    if let photo = try? await DependencyContainer.shared.stripRepository.fetchStrip(byId: stripId) {
                        // Gizli ve kilitli strip'leri deep link ile açma
                        let myId = Auth.auth().currentUser?.uid ?? ""
                        let isLocked = photo.isSecret == true && !(photo.unlockedBy ?? []).contains(myId) && photo.senderId != myId
                        guard !isLocked else { return }
                        await MainActor.run {
                            deepLinkReceiverId = (rcvId?.isEmpty == false) ? rcvId : nil
                            deepLinkStripPhoto = photo
                        }
                    }
                }
            }
            
        case "dm":
            // stripmate://dm/{threadId}  — threadId is "uid1_uid2"
            if let threadId = pathComponents.first, !threadId.isEmpty {
                Task {
                    let currentUserId = await DependencyContainer.shared.userRepository.currentUserProfile?.id ?? ""
                    let ids = threadId.split(separator: "_").map(String.init)
                    let partnerId = ids.first(where: { $0 != currentUserId }) ?? ids.first ?? ""
                    if !partnerId.isEmpty, let profile = try? await DependencyContainer.shared.userRepository.fetchProfile(for: partnerId) {
                        await MainActor.run {
                            deepLinkDMPartner = profile
                        }
                    }
                }
            }
            
        case "inbox":
            // Navigate to friends tab — messages are now integrated there
            selectedTab = .friends
            
        default:
            break
        }
    }

    // Breathing line is defined in BreathingUploadLine.swift

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    HapticsManager.playSelection()
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                                .frame(height: 26)
                            
                            // Badge
                            if tab == .friends && friendsPendingCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 16, height: 16)
                                    Text("\(friendsPendingCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                }
                                .offset(x: 6, y: -4)
                            }
                        }

                        Circle()
                            .fill(selectedTab == tab ? Color.white : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(tabAccessibilityLabel(for: tab))
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .padding(.horizontal, 44)
        .padding(.bottom, 24)
    }
    
    private func tabAccessibilityLabel(for tab: TabItem) -> String {
        switch tab {
        case .friends:
            if friendsPendingCount > 0 {
                return "\(tab.accessibilityName), \(friendsPendingCount) bekleyen istek"
            }
            return tab.accessibilityName
        case .history:
            return tab.accessibilityName
        default:
            return tab.accessibilityName
        }
    }
}
