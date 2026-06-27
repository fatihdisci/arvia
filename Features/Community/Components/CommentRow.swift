import SwiftUI

// MARK: - Comment Row
// Yorum satırı bileşeni.

struct CommentRow: View {
    let comment: CommunityComment
    var onReport: (() -> Void)?
    var onBlock: (() -> Void)?
    var onDelete: (() -> Void)?
    var isOwnComment: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Thread line — subtle visual anchor
            RoundedRectangle(cornerRadius: 1)
                .fill(AppColors.divider)
                .frame(width: 2)

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if comment.isDeleted || comment.isHidden {
                    deletedCommentView
                } else {
                    authorRow
                    Text(comment.body)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(minHeight: AppSpacing.minimumTapTarget)
        .padding(.vertical, AppSpacing.xs)
        .contextMenu {
            if !comment.isDeleted && !comment.isHidden {
                Button {
                    onReport?()
                } label: {
                    Label("Bildir", systemImage: "flag")
                }

                Button {
                    onBlock?()
                } label: {
                    Label("Kullanıcıyı Engelle", systemImage: "nosign")
                }

                if isOwnComment {
                    Divider()
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.authorEffectiveName): \(comment.isDeleted ? "Bu yorum kaldırıldı" : comment.body)")
    }

    // MARK: - Author Row

    private var authorRow: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "person.crop.circle.fill")
                .font(.callout)
                .foregroundColor(AppColors.textSecondary)

            Text(comment.authorEffectiveName)
                .font(AppTypography.secondaryMedium)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            if comment.authorIsVerified == true {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.accentPrimary)
                    .accessibilityLabel("Doğrulanmış")
            }

            if comment.authorRole == .admin {
                Text("Editör")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.accentPrimary)
                    .padding(.horizontal, AppSpacing.xxs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppColors.accentPrimary.opacity(0.12))
                    )
            }

            Text("·")
                .foregroundColor(AppColors.textTertiary)

            Text(comment.relativeTime)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Deleted/Hidden State

    private var deletedCommentView: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "eye.slash")
                .font(.subheadline)
                .foregroundColor(AppColors.warning)
            Text("Bu yorum kaldırıldı")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.surfaceSecondary.opacity(0.6))
        )
    }
}
