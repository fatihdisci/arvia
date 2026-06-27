import SwiftUI

// MARK: - Post Card
// Topluluk akışındaki gönderi kartı bileşeni.

struct PostCard: View {
    let post: CommunityPost
    var onLike: (() -> Void)?
    var onSave: (() -> Void)?
    var onReport: (() -> Void)?
    var onBlock: (() -> Void)?
    var onUnblock: (() -> Void)?

    @State private var showContextMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Author Row
            authorRow

            // Separator
            Divider()
                .foregroundColor(AppColors.divider)

            // Post meta — type chip + vehicle label
            postMetaRow

            // Title
            Text(post.title)
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)

            // Body preview
            Text(post.body)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)

            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xxs) {
                        ForEach(post.tags.prefix(5), id: \.self) { tag in
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

            // Stats footer
            statsRow
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .contentShape(Rectangle())
        .contextMenu {
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Detayları görmek için iki kere dokun. Basılı tutarak bildir veya engelle.")
    }

    // MARK: - Author Row

    private var authorRow: some View {
        HStack(spacing: AppSpacing.xs) {
            // Avatar placeholder
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundColor(AppColors.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(post.authorEffectiveName)
                        .font(AppTypography.secondaryMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    // Verified badge
                    if post.authorIsVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.accentPrimary)
                            .accessibilityLabel("Doğrulanmış hesap")
                    }

                    // Admin badge
                    if post.authorRole == .admin {
                        Text("Editör")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.accentPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(AppColors.accentPrimary.opacity(0.12))
                            )
                    }
                }

                HStack(spacing: 4) {
                    if let atUsername = post.authorAtUsername {
                        Text(atUsername)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Text("·")
                        .foregroundColor(AppColors.textTertiary)

                    Text(post.relativeTime)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)

                    // Pinned badge
                    if post.isPinned {
                        Text("·")
                            .foregroundColor(AppColors.textTertiary)
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundColor(AppColors.accentPrimary)
                        Text("Sabitlendi")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Post Meta Row (type chip + vehicle)

    @ViewBuilder
    private var postMetaRow: some View {
        let typeLabel = post.postType.displayName

        HStack(spacing: AppSpacing.xs) {
                // Post type chip
                HStack(spacing: 4) {
                    Image(systemName: post.postType.sfSymbol)
                        .font(AppTypography.captionMedium)
                    Text(typeLabel)
                        .font(AppTypography.captionMedium)
                }
                .foregroundColor(AppColors.accentPrimary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.accentPrimary.opacity(0.12))
                )

                // Vehicle label (if present)
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
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.lg) {
            // Likes
            Button {
                onLike?()
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
            .accessibilityLabel("\(post.likeCount) beğeni")
            .accessibilityHint(post.isLikedByCurrentUser ? "Beğeniyi kaldırmak için iki kere dokun" : "Beğenmek için iki kere dokun")

            // Comments
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.subheadline)
                Text("\(post.commentCount)")
                    .font(AppTypography.secondaryMedium)
            }
            .foregroundColor(AppColors.textSecondary)
            .accessibilityLabel("\(post.commentCount) yorum")

            Spacer()

            // Saves
            Button {
                onSave?()
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
            .accessibilityLabel("\(post.saveCount) kaydeden")
            .accessibilityHint(post.isSavedByCurrentUser ? "Kaydı kaldırmak için iki kere dokun" : "Kaydetmek için iki kere dokun")
        }
        .padding(.top, AppSpacing.xxs)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = "\(post.authorEffectiveName). \(post.title). \(post.postType.displayName). "
        if let vehicle = post.vehicleLabel {
            label += "Araç: \(vehicle). "
        }
        label += "\(post.likeCount) beğeni, \(post.commentCount) yorum. \(post.relativeTime)."
        return label
    }
}
