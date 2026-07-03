import SwiftUI

// MARK: - Section Header
// Bölüm başlıklarında tutarlılık sağlar.
// Opsiyonel aksiyon butonu ile kullanılabilir.
struct SectionHeader: View {
    let title: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        title: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Metric Card
// Sayısal metrik gösterimi için kullanılır.
// Raporlar, özet kartları, skor gösterimleri.
struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: LocalizedStringKey?
    let trend: MetricTrend?
    let icon: String?
    let iconColor: Color?

    enum MetricTrend {
        case up
        case down
        case neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return AppColors.critical
            case .down: return AppColors.success
            case .neutral: return AppColors.textTertiary
            }
        }
    }

    init(
        title: LocalizedStringKey,
        value: String,
        subtitle: LocalizedStringKey? = nil,
        trend: MetricTrend? = nil,
        icon: String? = nil,
        iconColor: Color? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.trend = trend
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(iconColor ?? AppColors.textTertiary)
                }

                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(AppTypography.amountLarge)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                HStack(spacing: AppSpacing.xxs) {
                    if let trend {
                        Image(systemName: trend.icon)
                            .font(.caption2)
                            .foregroundColor(trend.color)
                    }
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Text(title)): \(value)")
    }
}

// MARK: - Previews
#Preview("SectionHeader — Normal") {
    VStack {
        SectionHeader(title: "Yaklaşan İşler")
        SectionHeader(
            title: "Son Kayıtlar",
            actionTitle: "Tümü",
            action: {}
        )
    }
    .padding()
    .background(Color.appBackground)
}

#Preview("MetricCard — Grid") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
        MetricCard(
            title: "Yıllık Toplam",
            value: "₺42.850",
            subtitle: "Geçen yıla göre",
            trend: .down,
            icon: "chart.bar.fill",
            iconColor: AppColors.accentPrimary
        )
        MetricCard(
            title: "Km Başı Maliyet",
            value: "₺2,85",
            subtitle: "15.000 km",
            trend: .neutral,
            icon: "gauge.with.needle",
            iconColor: AppColors.vehicle
        )
        MetricCard(
            title: "Dosya Tamlığı",
            value: "%75",
            subtitle: "3 eksik belge",
            icon: "doc.text.fill",
            iconColor: AppColors.warning
        )
    }
    .padding()
    .background(Color.appBackground)
}

#Preview("MetricCard — Dark Mode") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
        MetricCard(
            title: "Yıllık Toplam",
            value: "₺42.850",
            subtitle: "Geçen yıla göre",
            trend: .down,
            icon: "chart.bar.fill",
            iconColor: AppColors.accentPrimary
        )
        MetricCard(
            title: "Dosya Tamlığı",
            value: "%75",
            subtitle: "3 eksik belge",
            icon: "doc.text.fill",
            iconColor: AppColors.warning
        )
    }
    .padding()
    .background(Color.appBackground)
}
