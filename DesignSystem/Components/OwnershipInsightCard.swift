import SwiftUI

// MARK: - Ownership Insight Card
// Raporlar ekranında "sahiplik içgörüsü" sunan kompakt metrik kartı.
// Km başı maliyet, en büyük gider, en masraflı ay gibi bilgiler.

struct OwnershipInsightCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }

            // Value
            Text(value)
                .font(.custom("JetBrainsMono-SemiBold", size: 18))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()

            // Subtitle — reserved line keeps 2×2 grid heights aligned
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(" ")
                    .font(AppTypography.caption)
                    .accessibilityHidden(true)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(subtitle.map { ". \($0)" } ?? "")")
    }
}

// MARK: - Premium Metric Hero
// Raporlar ekranı ana görsel çapası.
// "Bu yıl aracın sana ₺XX.XXX maliyet çıkardı" gibi anlatısal framing.

struct PremiumMetricHero: View {
    let label: String
    let value: String
    let vehicleName: String?
    let insightLine: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // Main label
            Text(label)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Hero value
            Text(value)
                .heroNumberStyle()
                .foregroundColor(AppColors.accentPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .monospacedDigit()

            // Vehicle context
            if let vehicleName {
                Text(vehicleName)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textTertiary)
            }

            // Insight line
            if let insightLine {
                Text(insightLine)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, AppSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenMarginH)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
            } else {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)\(vehicleName.map { ". \($0)" } ?? "")")
    }
}

// MARK: - Preview

#Preview("Insight Cards") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            PremiumMetricHero(
                label: "Bu yıl aracın sana",
                value: "₺45.320",
                vehicleName: "34 ABC 123 · Toyota Corolla",
                insightLine: "Geçen yıla göre %12 daha az"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                OwnershipInsightCard(
                    icon: "gauge.with.needle",
                    title: "Km Başı Maliyet",
                    value: "₺3,20",
                    subtitle: "14.200 km üzerinden",
                    color: AppColors.vehicle
                )
                OwnershipInsightCard(
                    icon: "arrow.up.right",
                    title: "En Büyük Gider",
                    value: "₺8.500",
                    subtitle: "Periyodik bakım",
                    color: AppColors.critical
                )
                OwnershipInsightCard(
                    icon: "calendar.badge.exclamationmark",
                    title: "En Masraflı Ay",
                    value: "₺12.750",
                    subtitle: "Mart 2026",
                    color: AppColors.warning
                )
                OwnershipInsightCard(
                    icon: "arrow.left.arrow.right",
                    title: "Bu Ay / Geçen Ay",
                    value: "₺1.200",
                    subtitle: "₺2.450 geçen ay",
                    color: AppColors.success
                )
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
}

#Preview("Insight Cards — Dark") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            PremiumMetricHero(
                label: "Bu yıl aracın sana",
                value: "₺45.320",
                vehicleName: "34 ABC 123 · Toyota Corolla",
                insightLine: "Geçen yıla göre %12 daha az"
            )
        }
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
}
