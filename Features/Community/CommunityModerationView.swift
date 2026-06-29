import SwiftUI

// MARK: - Community Moderation View
// Admin ve moderatör için şikayet yönetim ekranı.

/// Moderation action type for confirmation dialog.
enum ConfirmAction {
    case hidePost(CommunityReport)
    case hideComment(CommunityReport)
    case hardDeletePost(CommunityReport)
    case hardDeleteComment(CommunityReport)

    var report: CommunityReport {
        switch self {
        case .hidePost(let r): return r
        case .hideComment(let r): return r
        case .hardDeletePost(let r): return r
        case .hardDeleteComment(let r): return r
        }
    }
}

struct CommunityModerationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var communityAuth: CommunityAuthService

    @State private var selectedTab: ReportStatus = .pending
    @State private var reports: [CommunityReport] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var actionError: String?
    @State private var confirmAction: ConfirmAction?
    @State private var showConfirmation = false
    @State private var reportPreviews: [UUID: (reporter: String, content: String)] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Access guard
                if !(communityAuth.profile?.isModerator ?? false) {
                    EmptyStateView(
                        icon: "lock.shield",
                        title: "Erişim Yok",
                        description: "Bu bölüm yalnızca yönetici ve moderatörler içindir."
                    )
                } else {
                    // Segmented control
                    Picker("", selection: $selectedTab) {
                        Text("Bekleyen").tag(ReportStatus.pending)
                        Text("İncelendi").tag(ReportStatus.reviewed)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.vertical, AppSpacing.sm)

                    // Info banner
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accentPrimary)
                        Text("Moderasyon araçları yalnızca yönetici ve moderatörler içindir.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.bottom, AppSpacing.sm)

                    // Action error banner
                    if let actionError = actionError {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.critical)
                            Text(actionError)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.critical)
                            Spacer()
                            Button {
                                self.actionError = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenMarginH)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.criticalBackground)
                    }

                    // Content
                    if isLoading {
                        ProgressView()
                            .frame(maxHeight: .infinity)
                    } else if let error = error {
                        ErrorStateView(
                            title: "Yükleme Hatası",
                            message: "\(error)",
                            retryAction: { Task { await load() } }
                        )
                    } else if reports.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.shield",
                            title: selectedTab == .pending ? "Bekleyen bildirim yok" : "İncelenmiş bildirim yok",
                            description: ""
                        )
                    } else {
                        List {
                            ForEach(reports) { report in
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    HStack {
                                        Image(systemName: report.reason.sfSymbol)
                                            .foregroundColor(reportColor(report.reason))
                                        Text(report.reason.displayName)
                                            .font(AppTypography.captionMedium)
                                        Spacer()
                                        Text(report.createdAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textTertiary)
                                    }

                                    Text(report.targetLabel)
                                        .font(AppTypography.secondaryMedium)

                                    if let desc = report.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    // Reporter info and content preview
                                    if let preview = reportPreviews[report.id] {
                                        HStack(spacing: AppSpacing.xs) {
                                            Image(systemName: "person.circle")
                                                .font(.caption2)
                                                .foregroundColor(AppColors.textTertiary)
                                            Text(preview.reporter)
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textTertiary)
                                        }
                                        Text(preview.content)
                                            .font(AppTypography.secondarySmall)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(2)
                                    }

                                    if selectedTab == .pending {
                                        HStack(spacing: AppSpacing.sm) {
                                            Button("İncelendi") {
                                                Task { await markReviewed(report) }
                                            }
                                            .buttonStyle(.secondary)
                                            .controlSize(.small)

                                            Button(report.targetType == "post" ? "Gönderiyi Gizle" : "Yorumu Gizle") {
                                                confirmAction = report.targetType == "post"
                                                    ? .hidePost(report) : .hideComment(report)
                                                showConfirmation = true
                                            }
                                            .buttonStyle(.secondary)
                                            .controlSize(.small)

                                            Button(role: .destructive) {
                                                confirmAction = report.targetType == "post"
                                                    ? .hardDeletePost(report) : .hardDeleteComment(report)
                                                showConfirmation = true
                                            } label: {
                                                Text("Kalıcı Sil")
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColors.critical)
                                            }
                                            .controlSize(.small)
                                        }
                                    }
                                }
                                .padding(.vertical, AppSpacing.xxs)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Moderasyon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onChange(of: selectedTab) { _, _ in
                Task { await load() }
            }
            .task { await load() }
            .confirmationDialog(
                "Bu işlem geri alınamaz",
                isPresented: $showConfirmation,
                presenting: confirmAction
            ) { action in
                switch action {
                case .hidePost(let report):
                    Button("Gönderiyi Gizle", role: .destructive) {
                        Task { await hideContent(report) }
                    }
                case .hideComment(let report):
                    Button("Yorumu Gizle", role: .destructive) {
                        Task { await hideContent(report) }
                    }
                case .hardDeletePost(let report):
                    Button("Kalıcı Olarak Sil", role: .destructive) {
                        Task { await hardDeleteContent(report) }
                    }
                case .hardDeleteComment(let report):
                    Button("Kalıcı Olarak Sil", role: .destructive) {
                        Task { await hardDeleteContent(report) }
                    }
                }
                Button("Vazgeç", role: .cancel) {
                    confirmAction = nil
                }
            } message: { action in
                switch action {
                case .hidePost:
                    Text("Bu gönderi herkesten gizlenecek. Geri alınabilir.")
                case .hideComment:
                    Text("Bu yorum herkesten gizlenecek. Geri alınabilir.")
                case .hardDeletePost:
                    Text("Bu gönderi KALICI olarak silinecek. Bu işlem GERİ ALINAMAZ.")
                case .hardDeleteComment:
                    Text("Bu yorum KALICI olarak silinecek. Bu işlem GERİ ALINAMAZ.")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        actionError = nil
        do {
            reports = try await CommunityModerationService.shared.fetchReports(status: selectedTab)
            await loadPreviews()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadPreviews() async {
        for report in reports {
            guard reportPreviews[report.id] == nil else { continue }
            async let reporter = CommunityModerationService.shared.fetchReporterName(report.reporterId)
            let content: String?
            switch report.targetType {
            case "post":
                content = try? await CommunityModerationService.shared.fetchPostTitle(report.targetId)
            case "comment":
                content = try? await CommunityModerationService.shared.fetchCommentBody(report.targetId)
            default:
                content = nil
            }
            let reporterName = (try? await reporter) ?? "?"
            let previewContent = content ?? "(içerik bulunamadı)"
            reportPreviews[report.id] = (reporter: reporterName, content: previewContent)
        }
    }

    private func markReviewed(_ report: CommunityReport) async {
        do {
            try await CommunityModerationService.shared.markReportReviewed(report.id)
            await load()
        } catch {
            actionError = userFriendlyError(for: error, action: "İncelendi işaretlenemedi")
            #if DEBUG
            print("[Moderation] markReviewed error: \(error)")
            #endif
        }
    }

    private func hideContent(_ report: CommunityReport) async {
        defer {
            confirmAction = nil
            showConfirmation = false
        }
        do {
            switch report.targetType {
            case "post":
                try await CommunityModerationService.shared.hidePost(report.targetId)
            case "comment":
                try await CommunityModerationService.shared.hideComment(report.targetId)
            default:
                actionError = "Bilinmeyen içerik türü: \(report.targetType)"
                return
            }
            try await CommunityModerationService.shared.markReportReviewed(report.id)
            await load()
        } catch {
            actionError = userFriendlyError(for: error, action: "Gizlenemedi")
            #if DEBUG
            print("[Moderation] hideContent error: \(error)")
            #endif
        }
    }

    private func hardDeleteContent(_ report: CommunityReport) async {
        defer {
            confirmAction = nil
            showConfirmation = false
        }
        do {
            switch report.targetType {
            case "post":
                try await CommunityModerationService.shared.deletePostHard(report.targetId)
            case "comment":
                try await CommunityModerationService.shared.deleteCommentHard(report.targetId)
            default:
                actionError = "Bilinmeyen içerik türü: \(report.targetType)"
                return
            }
            try await CommunityModerationService.shared.markReportReviewed(report.id)
            await load()
        } catch {
            actionError = userFriendlyError(for: error, action: "Silinemedi")
            #if DEBUG
            print("[Moderation] hardDeleteContent error: \(error)")
            #endif
        }
    }

    /// Hata mesajını kullanıcı dostu hale getir. Release'de ham Supabase hatasını göstermez.
    private func userFriendlyError(for error: Error, action: String) -> String {
        #if DEBUG
        return "\(action): \(error.localizedDescription)"
        #else
        return "İşlem tamamlanamadı. Yetkini ve bağlantını kontrol edip tekrar deneyebilirsin."
        #endif
    }

    private func reportColor(_ reason: ReportReason) -> Color {
        switch reason {
        case .harassment, .inappropriate: return AppColors.critical
        case .misleading, .spam: return AppColors.warning
        case .personalInfo: return AppColors.critical
        case .other: return AppColors.textTertiary
        }
    }
}
