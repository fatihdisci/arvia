import SwiftUI

// MARK: - Arvia Rehber
// Yatay scroll carousel + bottom sheet ile kompakt insight gösterimi.
// Dikey alan kullanımı ~%40 azaltıldı.
struct ArviaGuideSection: View {
    let insights: [VehicleInsight]
    let vehicleId: UUID
    let onAction: (VehicleInsightAction) -> Void
    let onDismissInsight: (VehicleInsight) -> Void

    @State private var selectedInsight: VehicleInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Arvia Rehber")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Aracının kayıtlarına göre bakım, belge ve satış hazırlığı önerileri.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if insights.isEmpty {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.seal")
                        .font(.body)
                        .foregroundColor(AppColors.success.opacity(0.7))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Şimdilik öne çıkan öneri yok")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Kayıt ekledikçe Arvia Rehber genel önerilerini burada günceller.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            } else {
                // Yatay carousel — her insight kompakt kart
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: AppSpacing.sm) {
                        ForEach(insights) { insight in
                            CompactInsightCard(
                                insight: insight,
                                onTap: { selectedInsight = insight },
                                onDismiss: { onDismissInsight(insight) }
                            )
                            .containerRelativeFrame(.horizontal, count: 1, spacing: AppSpacing.sm)
                            .id(insight.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }

            arviaGuideDisclaimer
        }
        .sheet(item: $selectedInsight) { insight in
            InsightDetailSheet(
                insight: insight,
                onAction: { action in
                    selectedInsight = nil
                    onAction(action)
                },
                onDismiss: {
                    selectedInsight = nil
                    onDismissInsight(insight)
                }
            )
        }
    }

    private var arviaGuideDisclaimer: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
                .accessibilityHidden(true)
            Text("Arvia Rehber, araç kayıtlarına göre genel öneriler sunar.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Compact Insight Card (Carousel)
private struct CompactInsightCard: View {
    let insight: VehicleInsight
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Üst satır: ikon + dismiss
                HStack(alignment: .top) {
                    Image(systemName: iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(iconColor.opacity(0.12)))

                    Spacer()

                    if insight.contentKind != .callToAction {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Öneriyi kapat")
                    }
                }

                // Başlık + body (maks 2 satır)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(insight.body)
                        .font(AppTypography.secondarySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                // Alt: "detay için dokun" hint'i
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .frame(width: 280, height: 152)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tam metin için çift tıkla")
    }

    // MARK: - Icon / Color per content kind
    private var iconName: String {
        switch insight.contentKind {
        case .callToAction: return "exclamationmark.triangle.fill"
        case .info:         return "info.circle.fill"
        case .warning:      return "exclamationmark.octagon.fill"
        case .reminder:     return "bell.fill"
        case .softQuestion: return "questionmark.bubble.fill"
        }
    }

    private var iconColor: Color {
        switch insight.contentKind {
        case .callToAction: return AppColors.critical
        case .info:         return AppColors.accentPrimary
        case .warning:      return AppColors.warning
        case .reminder:     return AppColors.accentSecondary
        case .softQuestion: return AppColors.accentPrimary
        }
    }
}

// MARK: - Insight Detail Sheet
private struct InsightDetailSheet: View {
    let insight: VehicleInsight
    let onAction: (VehicleInsightAction) -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(iconColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text(contentKindLabel)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                Button {
                    onDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Tam metin
            ScrollView {
                Text(insight.body)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Aksiyon butonu
            if let action = insight.action, insight.contentKind != .callToAction {
                Button {
                    onAction(action)
                    dismiss()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text(action.title)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .buttonStyle(.primary)
                .frame(minHeight: AppSpacing.minimumTapTarget)
            }
        }
        .padding(AppSpacing.lg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Icon / Color
    private var iconName: String {
        switch insight.contentKind {
        case .callToAction: return "exclamationmark.triangle.fill"
        case .info:         return "info.circle.fill"
        case .warning:      return "exclamationmark.octagon.fill"
        case .reminder:     return "bell.fill"
        case .softQuestion: return "questionmark.bubble.fill"
        }
    }

    private var iconColor: Color {
        switch insight.contentKind {
        case .callToAction: return AppColors.critical
        case .info:         return AppColors.accentPrimary
        case .warning:      return AppColors.warning
        case .reminder:     return AppColors.accentSecondary
        case .softQuestion: return AppColors.accentPrimary
        }
    }

    private var contentKindLabel: String {
        switch insight.contentKind {
        case .callToAction: return "Önerilen İşlem"
        case .info:         return "Bilgi"
        case .warning:      return "Uyarı"
        case .reminder:     return "Hatırlatma"
        case .softQuestion: return "Öneri"
        }
    }
}
