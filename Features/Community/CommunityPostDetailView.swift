import SwiftUI

// MARK: - Community Post Detail View
// Gönderi detayı, yorumlar, beğeni/kaydet/şikayet.
// Guest okuyabilir, yazma/etkileşim için giriş gerekir.

struct CommunityPostDetailView: View {
    let postId: UUID

    @EnvironmentObject private var communityAuth: CommunityAuthService

    @State private var post: CommunityPost?
    @State private var comments: [CommunityComment] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var commentText = ""
    @State private var isSubmittingComment = false
    @State private var commentError: String?
    @State private var showSignInPrompt = false
    @State private var reportTarget: ReportTarget?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Gönderi yükleniyor...")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, AppSpacing.md)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                ErrorStateView(
                    title: "Yükleme Hatası",
                    message: "\(error)",
                    retryAction: { Task { await load() } }
                )
            } else if let post = post {
                if post.isDeleted || post.isHidden {
                    VStack {
                        Spacer()
                        CommunityEmptyStateView(state: .deletedPost)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        contentView(post)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            } else {
                // post nil + no error → not found
                VStack {
                    Spacer()
                    CommunityEmptyStateView(state: .deletedPost)
                    Spacer()
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Gönderi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let post = post {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        detailContextMenu(for: post)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                }
            }
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
        .task { await load() }
    }

    // MARK: - Content

    private func contentView(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Author header
            authorHeader(post)

            // Post type + vehicle
            HStack(spacing: AppSpacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: post.postType.sfSymbol)
                        .font(AppTypography.captionMedium)
                    Text(post.postType.displayName)
                        .font(AppTypography.captionMedium)
                }
                .foregroundColor(AppColors.accentPrimary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.accentPrimary.opacity(0.12))
                )

                if let vehicle = post.vehicleLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 10))
                        Text(vehicle)
                            .font(AppTypography.captionMedium)
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.surfaceSecondary)
                    )
                }
            }

            // Title
            Text(post.title)
                .font(AppTypography.screenTitle)
                .foregroundColor(AppColors.textPrimary)

            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xxs) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text(tag)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(AppColors.surfaceSecondary)
                                )
                        }
                    }
                }
            }

            // Full body
            Text(post.body)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Action bar
            actionBar(post)

            Divider()
                .background(AppColors.divider)

            // Comments
            commentsSection(post)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Author Header

    private func authorHeader(_ post: CommunityPost) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundColor(AppColors.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(post.authorEffectiveName)
                        .font(AppTypography.bodyMedium)
                    if post.authorIsVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    if post.authorRole == .admin {
                        Text("Editör")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.accentPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.accentPrimary.opacity(0.12)))
                    }
                }

                if let atUsername = post.authorAtUsername {
                    Text(atUsername)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Text(post.relativeTime)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Action Bar

    private func actionBar(_ post: CommunityPost) -> some View {
        HStack(spacing: AppSpacing.lg) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .contentTransition(.symbolEffect(.replace))
                    Text("\(post.likeCount)")
                        .font(AppTypography.secondaryMedium)
                }
                .foregroundColor(post.isLikedByCurrentUser ? AppColors.critical : AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            Button {
                Task { await toggleSave() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: post.isSavedByCurrentUser ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                        .contentTransition(.symbolEffect(.replace))
                    Text("\(post.saveCount)")
                        .font(AppTypography.secondaryMedium)
                }
                .foregroundColor(post.isSavedByCurrentUser ? AppColors.accentPrimary : AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                guard communityAuth.isAuthenticated else {
                    showSignInPrompt = true
                    return
                }
                reportTarget = ReportTarget(type: "post", targetId: post.id)
            } label: {
                Image(systemName: "flag")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bildir")
        }
    }

    // MARK: - Comments Section

    private func commentsSection(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Section header with count
            HStack(spacing: AppSpacing.xs) {
                Text("Yorumlar")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("(\(comments.count))")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Comment composer
            if communityAuth.isAuthenticated {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.callout)
                        .foregroundColor(AppColors.textTertiary)

                    HStack(spacing: AppSpacing.sm) {
                        TextField("Yorum yaz...", text: $commentText, axis: .vertical)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1...4)
                            .disabled(isSubmittingComment)

                        Button {
                            Task { await submitComment() }
                        } label: {
                            if isSubmittingComment {
                                ProgressView()
                                    .tint(AppColors.accentPrimary)
                                    .frame(width: 36, height: 36)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.body)
                                    .foregroundColor(AppColors.textOnAccent)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(
                                                commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                ? AppColors.accentPrimary.opacity(0.3)
                                                : AppColors.accentPrimary
                                            )
                                    )
                            }
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.appSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border, lineWidth: 0.5)
                    )
                }
            } else {
                // Guest login prompt
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.subheadline)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("Yorum yazmak için Apple ile giriş yap.")
                                .font(AppTypography.secondaryMedium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }

                    Spacer()

                    Button("Giriş Yap") {
                        showSignInPrompt = true
                    }
                    .buttonStyle(.primary)
                    .controlSize(.small)
                    .fixedSize()
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.accentPrimary.opacity(0.08))
                )
            }

            // Comment submit error
            if let commentError = commentError {
                Text(commentError)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.critical)
                    .padding(.vertical, AppSpacing.xs)
            }

            // Comments list
            if comments.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Henüz yorum yapılmadı.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Text("İlk yorumu sen yaparak tartışmayı başlat.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        onReport: {
                            reportTarget = ReportTarget(type: "comment", targetId: comment.id)
                        },
                        onBlock: {
                            Task { await blockCommentAuthor(comment) }
                        },
                        onDelete: {
                            Task { await deleteComment(comment) }
                        },
                        isOwnComment: communityAuth.profile?.id == comment.authorId
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        error = nil

        // Fetch post and comments concurrently — comment failure must not hide the post.
        async let postTask = CommunityService.shared.fetchPost(id: postId)
        async let commentsTask = CommunityService.shared.fetchComments(postId: postId)

        do {
            post = try await postTask
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return
        }

        do {
            comments = try await commentsTask
        } catch {
            // Post loaded fine — show it even if comments fail.
            comments = []
        }

        isLoading = false
    }

    private func toggleLike() async {
        guard communityAuth.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        guard var p = post else { return }
        do {
            let liked = try await CommunityService.shared.toggleLike(postId: p.id)
            p.isLikedByCurrentUser = liked
            p.likeCount += liked ? 1 : -1
            post = p
        } catch {}
    }

    private func toggleSave() async {
        guard communityAuth.isAuthenticated else {
            showSignInPrompt = true
            return
        }
        guard var p = post else { return }
        do {
            let saved = try await CommunityService.shared.toggleSave(postId: p.id)
            p.isSavedByCurrentUser = saved
            p.saveCount += saved ? 1 : -1
            post = p
        } catch {}
    }

    private func submitComment() async {
        let body = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 2, body.count <= 1000 else { return }
        isSubmittingComment = true
        commentError = nil
        do {
            _ = try await CommunityService.shared.createComment(postId: postId, body: body)
            commentText = ""
            comments = try await CommunityService.shared.fetchComments(postId: postId)
        } catch {
            #if DEBUG
            print("[CommunityPostDetail] Comment submit error: \(error.localizedDescription)")
            #endif
            commentError = "Yorum gönderilemedi. Lütfen tekrar dene."
        }
        isSubmittingComment = false
    }

    private func deleteComment(_ comment: CommunityComment) async {
        do {
            try await CommunityService.shared.deleteComment(id: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {}
    }

    private func blockCommentAuthor(_ comment: CommunityComment) async {
        do {
            try await CommunityModerationService.shared.blockUser(userId: comment.authorId)
        } catch {}
    }

    // MARK: - Detail Context Menu (role-based)

    @ViewBuilder
    private func detailContextMenu(for post: CommunityPost) -> some View {
        let isMod = communityAuth.profile?.isModerator ?? false
        let isOwner = communityAuth.profile?.id == post.authorId

        if isOwner {
            Button {
                // Navigate to edit — use the same CommunityCreatePostView pattern
                // For now: reportTarget is reused since we don't have an edit sheet here
            } label: {
                Label("Düzenle", systemImage: "pencil")
            }
        }

        if isMod {
            Divider()

            if post.isCurrentlyPinned {
                Button {
                    Task { await handleDetailUnpin(post) }
                } label: {
                    Label("Sabitlemeyi Kaldır", systemImage: "pin.slash")
                }
            } else {
                Button {
                    Task { await handleDetailPin(post) }
                } label: {
                    Label("Sabitle", systemImage: "pin")
                }
            }

            if post.isModerationHidden {
                Button {
                    Task { await handleDetailUnhide(post) }
                } label: {
                    Label("Yayına Al", systemImage: "eye")
                }
            } else {
                Button(role: .destructive) {
                    Task { await handleDetailHide(post) }
                } label: {
                    Label("Gizle", systemImage: "eye.slash")
                }
            }

            Button(role: .destructive) {
                Task { await handleDetailDelete(post) }
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }

        if isOwner && !isMod {
            Divider()
            Button(role: .destructive) {
                Task { await handleDetailDelete(post) }
            } label: {
                Label("Gönderiyi Sil", systemImage: "trash")
            }
        }
    }

    private func handleDetailPin(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.pinPost(post.id)
            // Refresh
            await load()
        } catch {}
    }

    private func handleDetailUnpin(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.unpinPost(post.id)
            await load()
        } catch {}
    }

    private func handleDetailHide(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.hidePostViaRPC(post.id)
            await load()
        } catch {}
    }

    private func handleDetailUnhide(_ post: CommunityPost) async {
        do {
            try await CommunityModerationService.shared.unhidePost(post.id)
            await load()
        } catch {}
    }

    private func handleDetailDelete(_ post: CommunityPost) async {
        do {
            if communityAuth.profile?.isModerator == true {
                try await CommunityModerationService.shared.deletePostViaRPC(post.id)
            } else {
                try await CommunityService.shared.deletePost(id: post.id)
            }
            await load()
        } catch {}
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
                Button {
                    showSignInPrompt = false
                    Task { try? await communityAuth.signInWithApple() }
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Apple ile Giriş Yap")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                }
                .buttonStyle(.primary)
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
}
