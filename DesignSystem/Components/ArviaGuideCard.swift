import SwiftUI

// MARK: - Vehicle Insight Card
// Arvia Rehber 5 içerik tipi (CTA/Bilgi/Uyarı/Hatırlatma/Soru) için birleşik kart.
// Karar 4.2 + Gemini raporu Bölüm 5.4.
// - .callToAction dışındaki tüm tipler için sağ üstte dismiss butonu
// - .softQuestion çift buton (Ekle + Şimdi Değil)
// - .warning inline CTA + dismiss
// - .info / .reminder sadece dismiss
struct VehicleInsightCard: View {
    let insight: VehicleInsight
    let vehicleId: UUID
    var onAction: (VehicleInsightAction) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Üst satır: ikon + başlık/gövde + (varsa) dismiss butonu
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(iconColor.opacity(0.12)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(insight.body)
                        .font(AppTypography.secondarySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.xs)

                if insight.contentKind != .callToAction {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Öneriyi kapat")
                }
            }

            // Alt satır: içerik tipine göre CTA buton(lar)ı
            actionButtons
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Action Buttons (per content kind)

    @ViewBuilder
    private var actionButtons: some View {
        switch insight.contentKind {
        case .callToAction:
            // Tek zorunlu buton
            if let action = insight.action {
                Button { onAction(action) } label: {
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

        case .softQuestion:
            // Çift buton: action + "Şimdi Değil"
            HStack(spacing: AppSpacing.sm) {
                if let action = insight.action {
                    Button { onAction(action) } label: {
                        Text(action.title)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                }
                Button(action: onDismiss) {
                    Text("Şimdi Değil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
            }
            .frame(minHeight: AppSpacing.minimumTapTarget)

        case .warning:
            // Inline CTA + dismiss butonu (dismiss zaten üstte, ek satır)
            if let action = insight.action {
                Button { onAction(action) } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text(action.title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .buttonStyle(.text)
                .frame(minHeight: AppSpacing.minimumTapTarget)
            }

        case .info, .reminder:
            // Sadece dismiss (zaten üstte)
            EmptyView()
        }
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

    private var accessibilityLabel: String {
        var parts = [insight.title, insight.body]
        if let action = insight.action, insight.contentKind != .callToAction, !action.title.isEmpty {
            parts.append(action.title)
        }
        return parts.joined(separator: ". ")
    }
}