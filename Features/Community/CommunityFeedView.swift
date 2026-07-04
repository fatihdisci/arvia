import SwiftUI
import AuthenticationServices

// MARK: - Community Feed View
// Topluluk ana ekranı. Guest okuyabilir, yazmak için giriş gerekir.

/// Post detay sheet için Identifiable wrapper (UUID'ye extension yerine).
struct PostDetailTarget: Identifiable {
    let id = UUID()
    let postId: UUID
}

struct CommunityFeedView: View {
    @EnvironmentObject private var communityAuth: CommunityAuthService
    @EnvironmentObject private var paywallService: PaywallService
    private let previewPosts: [CommunityPost]?

    @State private var posts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedType: PostType?
    @State private var selectedTags: Set<String> = []
    @State private var showProfile = false
    @State private var showCreatePost = false
    @State private var selectedPostId: PostDetailTarget?
    @State private var showModeration = false
    @State private var showModerationCenter = false
    @State private var showSignInPrompt = false
    @State private var reportTarget: ReportTarget?
    @State private var editingPost: CommunityPost?
    @State private var confirmAction: ModerationConfirmAction?

    // Profile creation (first-time)
    @State private var usernameInput = ""
    @State private var displayNameInput = ""
    @State private var profileValidationError: String?
    @State private var isCreatingProfile = false
    @State private var usernameAvailability: UsernameAvailability = .unknown

    enum UsernameAvailability: Equatable {
        case unknown
        case checking
        case available
        case taken
    }

    init(previewPosts: [CommunityPost]? = nil) {
        self.previewPosts = previewPosts
        _posts = State(initialValue: previewPosts ?? [])
        _isLoading = State(initialValue: previewPosts == nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if previewPosts == nil && !communityAuth.isCommunityAvailable {
                    configMissingView
                } else if communityAuth.isSigningIn {
                    signingInView
                } else if communityAuth.isAuthenticated && communityAuth.needsProfileCreation {
                    profileCreationView
                } else {
                    feedView
                }
            }
            .navigationTitle("Topluluk")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                if communityAuth.isAuthenticated && !communityAuth.needsProfileCreation {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: AppSpacing.sm) {
                            // Moderation (admin/moderator only)
                            if communityAuth.profile?.isModerator == true {
                                Button {
                                    showModerationCenter = true
                                } label: {
                                    Image(systemName: "shield")
                                        .foregroundColor(AppColors.accentPrimary)
                                }
                                .accessibilityLabel("Moderasyon Merkezi")
                            }

                            // Create post
                            Button {
                                handleCreatePostTap()
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(AppColors.accentPrimary)
                            }
                            .accessibilityLabel("Yeni Gönderi")

                            // Profile
                            Button {
                                showProfile = true
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(AppColors.accentPrimary)
                            }
                            .accessibilityLabel("Profil")
                        }
                    }
                } else if !communityAuth.isAuthenticated && communityAuth.isCommunityAvailable {
                    // Guest: toolbar'da sade metin CTA — asıl tam genişlik
                    // Sign in with Apple butonu signInPromptSheet içinde (HIG).
                    // Toolbar'a sıkıştırılmış mini Apple butonu, iOS 26 cam
                    // toolbar kapsülüyle çift çerçeve görünümü yaratıyordu.
                    ToolbarItem(placement: .primaryAction) {
                        Button("Giriş Yap") {
                            showSignInPrompt = true
                        }
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                        .accessibilityLabel("Topluluğa giriş yap")
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                CommunityProfileView()
            }
            .sheet(isPresented: $showCreatePost, onDismiss: {
                editingPost = nil
                Task { await refreshPosts() }
            }) {
                CommunityCreatePostView(editingPost: editingPost)
            }
            .sheet(item: $selectedPostId) { target in
                CommunityPostDetailView(postId: target.postId)
            }
            .sheet(isPresented: $showModerationCenter) {
                CommunityModerationCenterView()
                    .environmentObject(communityAuth)
            }
            .sheet(isPresented: $showSignInPrompt) {
                signInPromptSheet
            }
            .sheet(item: $reportTarget) { target in
                ReportReasonSheet(
                    targetType: target.type,
                    targetId: target.targetId,
                    onDismiss: { reportTarget = nil }
                )
            }
            .confirmationDialog(
                confirmAction?.title ?? "",
                isPresented: .constant(confirmAction != nil),
                presenting: confirmAction
            ) { action in
                Button(role: .destructive) {
                    Task { await executeConfirmAction(action) }
                } label: {
                    Text(action.buttonLabel)
                }
                Button("Vazgeç", role: .cancel) {
                    confirmAction = nil
                }
            } message: { action in
                Text(action.message)
            }
        }
        .environmentObject(communityAuth)
    }

    // MARK: - Sign-In Prompt Sheet
    private var signInPromptSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(AppColors.accentPrimary)
                Text("Topluluğa katılmak için Apple ile giriş yap.")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        communityAuth.handleSignInResult(result)
                        showSignInPrompt = false
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
            .background(Color.appBackground)
            .navigationTitle("Giriş Yap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showSignInPrompt = false }
                }
            }
        }
    }

    // MARK: - Config Missing

    private var configMissingView: some View {
        CommunityEmptyStateView(state: .configMissing)
    }

    // MARK: - Signing In

    private var signingInView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Giriş yapılıyor...")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Profile Creation (inline)

    private var profileCreationView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.floatingTabBarContentInset)

                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(AppColors.accentPrimary)

                    Text("Profilini oluşturalım")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Toplulukta güvenli bir deneyim için kullanıcı adını belirle.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.screenMarginH)

                VStack(spacing: AppSpacing.md) {
                    // Username field
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "at")
                                .font(.body)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)
                            TextField("kullanici_adin", text: $usernameInput)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: usernameInput) { _, newValue in
                                    checkUsernameDebounced(newValue)
                                }

                            // Availability indicator
                            if usernameAvailability == .checking {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else if usernameAvailability == .available {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accentPrimary)
                                    .font(.subheadline)
                                    .accessibilityLabel("Kullanıcı adı müsait")
                            } else if usernameAvailability == .taken {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.critical)
                                    .font(.subheadline)
                                    .accessibilityLabel("Kullanıcı adı alınmış")
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(Color.appSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.border, lineWidth: 1)
                        )

                        Text("Kullanıcı adın toplulukta herkese açık görünecek. Plaka bilgini paylaşma.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, 4)
                    }

                    // Display name field
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "person.text.rectangle")
                                .font(.body)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)
                            TextField("Görünen ad (isteğe bağlı)", text: $displayNameInput)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(Color.appSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }

                    // Tips
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("💡 İpuçları")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "1.circle.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("Kullanıcı adın herkese açık görünür. Gerçek adın olmak zorunda değil.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "2.circle.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("3-20 karakter, sadece harf, rakam ve alt çizgi (_) kullanabilirsin.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "3.circle.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("Profilini oluşturmadan gönderi paylaşamaz, yorum yapamaz veya beğenemezsin.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(AppColors.accentPrimary.opacity(0.06))
                    )

                    if let error = profileValidationError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.critical)
                    }
                }
                .padding(.horizontal, AppSpacing.screenMarginH)

                Button {
                    createProfile()
                } label: {
                    HStack {
                        if isCreatingProfile {
                            ProgressView()
                                .tint(AppColors.textOnAccent)
                        }
                        Text("Profili Oluştur")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.screenMarginH)
                .disabled(isCreatingProfile || usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Feed View

    private var feedView: some View {
        VStack(spacing: 0) {
            // Filter chips
            CommunityFilterChips(selectedType: $selectedType, selectedTags: $selectedTags)
                .padding(.vertical, AppSpacing.xs)
                .onChange(of: selectedType) { _, _ in
                    Task { await loadPosts() }
                }

            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Gönderiler yükleniyor...")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, AppSpacing.md)
                Spacer()
            } else if let error = error {
                Spacer()
                ErrorStateView(
                    title: "Yükleme Hatası",
                    message: "\(error)",
                    retryAction: { Task { await loadPosts() } }
                )
                Spacer()
            } else if posts.isEmpty {
                Spacer()
                CommunityEmptyStateView(state: .noPosts)
                Spacer()
            } else {
                List {
                    ForEach(posts) { post in
                        let isMod = communityAuth.profile?.isModerator ?? false
                        let isOwner = communityAuth.profile?.id == post.authorId

                        PostCard(
                            post: post,
                            onLike: { Task { await handleLike(post) } },
                            onSave: { Task { await handleSave(post) } },
                            onReport: { handleReport(post) },
                            onBlock: { Task { await handleBlock(post) } },
                            onPin: { Task { await handlePin(post) } },
                            onUnpin: { Task { await handleUnpin(post) } },
                            onHide: { confirmAction = .hidePost(post) },
                            onUnhide: { Task { await handleUnhide(post) } },
                            onDelete: { confirmAction = .deletePost(post) },
                            onEdit: { handleEdit(post) },
                            onViewReports: {
                                showModerationCenter = true
                            },
                            onShare: { handleShare(post) },
                            isCurrentUserModerator: isMod,
                            isCurrentUserPostOwner: isOwner
                        )
                        .listRowInsets(EdgeInsets(
                            top: AppSpacing.xs,
                            leading: AppSpacing.screenMarginH,
                            bottom: AppSpacing.xs,
                            trailing: AppSpacing.screenMarginH
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPostId = PostDetailTarget(postId: post.id)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refreshPosts()
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .task {
            await loadPosts()
        }
    }

    // MARK: - Actions

    private func loadPosts() async {
        if let previewPosts {
            posts = filteredPreviewPosts(previewPosts)
            isLoading = false
            error = nil
            return
        }

        isLoading = true
        error = nil
        do {
            posts = try await CommunityService.shared.fetchPosts(type: selectedType)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func refreshPosts() async {
        if let previewPosts {
            posts = filteredPreviewPosts(previewPosts)
            error = nil
            return
        }

        do {
            posts = try await CommunityService.shared.fetchPosts(type: selectedType)
            error = nil
        } catch {
            // Keep existing posts on refresh error
        }
    }

    private func filteredPreviewPosts(_ source: [CommunityPost]) -> [CommunityPost] {
        guard let selectedType else { return source }
        return source.filter { $0.postType == selectedType }
    }

    private func handleLike(_ post: CommunityPost) async {
        guard communityAuth.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        do {
            let isLiked = try await CommunityService.shared.toggleLike(postId: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isLikedByCurrentUser = isLiked
                posts[index].likeCount += isLiked ? 1 : -1
            }
        } catch {
            // Silently fail — user can retry
        }
    }

    private func handleSave(_ post: CommunityPost) async {
        guard communityAuth.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        do {
            let isSaved = try await CommunityService.shared.toggleSave(postId: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isSavedByCurrentUser = isSaved
                posts[index].saveCount += isSaved ? 1 : -1
            }
        } catch {
            // Silently fail
        }
    }

    private func handleReport(_ post: CommunityPost) {
        guard communityAuth.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        reportTarget = ReportTarget(type: "post", targetId: post.id)
    }

    private func handleBlock(_ post: CommunityPost) async {
        guard communityAuth.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        do {
            try await CommunityModerationService.shared.blockUser(userId: post.authorId)
        } catch {
            // Silently fail
        }
    }

    // MARK: - Moderation Handlers

    private func handlePin(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.pinPost(post.id)
            await refreshPosts()
        } catch {
            // Silently fail
        }
    }

    private func handleUnpin(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.unpinPost(post.id)
            await refreshPosts()
        } catch {
            // Silently fail
        }
    }

    private func handleHide(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.hidePostViaRPC(post.id)
            await refreshPosts()
        } catch {
            // Silently fail
        }
    }

    private func handleUnhide(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.unhidePost(post.id)
            await refreshPosts()
        } catch {
            // Silently fail
        }
    }

    private func handleModDelete(_ post: CommunityPost) async {
        do {
            if communityAuth.profile?.isModerator == true {
                try await CommunityModerationService.shared.deletePostViaRPC(post.id)
            } else {
                try await CommunityService.shared.deletePost(id: post.id)
            }
            await refreshPosts()
        } catch {
            // Silently fail
        }
    }

    private func handleEdit(_ post: CommunityPost) {
        editingPost = post
        showCreatePost = true
    }

    private func handleShare(_ post: CommunityPost) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let root = window.rootViewController else { return }

        let text = "\(post.title) — Arvia Topluluk"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        root.present(av, animated: true)
    }

    private func executeConfirmAction(_ action: ModerationConfirmAction) async {
        confirmAction = nil
        switch action {
        case .hidePost(let post):
            await handleHide(post)
        case .deletePost(let post):
            await handleModDelete(post)
        }
    }

    // MARK: - Username Availability

    @State private var usernameCheckTask: Task<Void, Never>?

    private func checkUsernameDebounced(_ username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            usernameAvailability = .unknown
            return
        }

        usernameCheckTask?.cancel()

        // Debounce: sadece 400ms sessizlikten sonra kontrol et
        usernameCheckTask = Task {
            usernameAvailability = .checking
            try? await Task.sleep(nanoseconds: 400_000_000)

            guard !Task.isCancelled else { return }

            do {
                let isAvailable = try await CommunityProfileService.shared.checkUsernameAvailability(trimmed)
                guard !Task.isCancelled else { return }
                usernameAvailability = isAvailable ? .available : .taken
            } catch {
                guard !Task.isCancelled else { return }
                usernameAvailability = .unknown
            }
        }
    }

    private func handleCreatePostTap() {
        if communityAuth.isAuthenticated {
            showCreatePost = true
        } else {
            showSignInPrompt = true
        }
    }

    private func createProfile() {
        let trimmedUsername = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if let error = CommunityProfile.validateUsername(trimmedUsername) {
            profileValidationError = error
            return
        }

        if let error = CommunityProfile.validateDisplayName(
            displayNameInput.isEmpty ? nil : displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            profileValidationError = error
            return
        }

        profileValidationError = nil
        isCreatingProfile = true

        Task {
            do {
                guard let session = communityAuth.currentSession else {
                    profileValidationError = "Oturum bulunamadı. Lütfen tekrar giriş yap."
                    isCreatingProfile = false
                    return
                }

                // Check username availability before creating
                let isAvailable = try await CommunityProfileService.shared.checkUsernameAvailability(trimmedUsername)
                guard isAvailable else {
                    profileValidationError = "Bu kullanıcı adı zaten alınmış. Lütfen başka bir tane dene."
                    isCreatingProfile = false
                    return
                }

                let userId = session.user.id
                let displayName = displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

                _ = try await CommunityProfileService.shared.createProfile(
                    userId: userId,
                    username: trimmedUsername,
                    displayName: displayName.isEmpty ? nil : displayName
                )

                await communityAuth.fetchProfile(userId: userId)
                isCreatingProfile = false
            } catch {
                profileValidationError = "Profil oluşturulamadı: \(error.localizedDescription)"
                isCreatingProfile = false
            }
        }
    }
}

// MARK: - Moderation Confirm Action

enum ModerationConfirmAction: Identifiable {
    case hidePost(CommunityPost)
    case deletePost(CommunityPost)

    var id: String {
        switch self {
        case .hidePost: return "hide"
        case .deletePost: return "delete"
        }
    }

    var title: String {
        switch self {
        case .hidePost: return "Post Gizlensin mi?"
        case .deletePost: return "Post Silinsin mi?"
        }
    }

    var message: String {
        switch self {
        case .hidePost(let post):
            return "\"\(post.title)\" başlıklı post gizlenecek. Kullanıcılar artık göremez."
        case .deletePost(let post):
            return "\"\(post.title)\" başlıklı post silinecek. Bu işlem geri alınamaz."
        }
    }

    var buttonLabel: String {
        switch self {
        case .hidePost: return "Gizle"
        case .deletePost: return "Sil"
        }
    }
}

// MARK: - Preview

#Preview("Signed Out") {
    CommunityFeedView()
        .environmentObject(CommunityAuthService.shared)
        .environmentObject(PaywallService.shared)
}

#Preview("Config Missing") {
    CommunityFeedView()
        .environmentObject(CommunityAuthService.shared)
        .environmentObject(PaywallService.shared)
}

#Preview("Topluluk — Dolu") {
    CommunityFeedView(previewPosts: MockDataProvider.previewCommunityPosts())
        .environmentObject(CommunityAuthService.shared)
        .environmentObject(PaywallService.shared)
}

#Preview("Topluluk — Dolu Dark") {
    CommunityFeedView(previewPosts: MockDataProvider.previewCommunityPosts())
        .environmentObject(CommunityAuthService.shared)
        .environmentObject(PaywallService.shared)
}
