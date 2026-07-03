import SwiftUI

// MARK: - Vehicle Card
// Garaj ekranında gösterilen ana araç kartı.
// Tek görsel çapa prensibi: Kartın kendisi ekrandaki ana öğe.

struct VehicleCard: View {
    let vehicle: Vehicle
    let upcomingReminderTitle: String?
    let upcomingReminderStatus: ReminderStatus?
    let fileCompletenessScore: Int? // 0-100

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Hero Section
            heroSection

            Divider()
                .foregroundColor(AppColors.divider)
                .padding(.horizontal, AppSpacing.md)

            // MARK: Info Row
            infoRow

            // MARK: Status Footer (yaklaşan iş + dosya tamlık)
            if upcomingReminderTitle != nil || fileCompletenessScore != nil {
                Divider()
                    .foregroundColor(AppColors.divider)
                    .padding(.horizontal, AppSpacing.md)

                statusFooter
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(vehicle.fullName), \(vehicle.plate)")
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Plaka — ana görsel çapa
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(vehicle.plate.isEmpty ? "—" : vehicle.plate)
                    .plateTextStyle()
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Yakıt tipi badge
                Text(vehicle.fuelType.displayName)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.accentMuted)
                    )
            }

            // Marka Model
            Text(vehicle.fullName.isEmpty ? "Marka Model" : vehicle.fullName)
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)

            // Nickname varsa
            if !vehicle.nickname.isEmpty {
                Text(vehicle.nickname)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.accentPrimary)
                    .padding(.top, 2)
            }
        }
        .padding(AppSpacing.md)
    }

    // MARK: - Info Row
    private var infoRow: some View {
        HStack(spacing: AppSpacing.lg) {
            infoItem(icon: "calendar", label: "Yıl", value: vehicle.yearDisplay)
            infoItem(icon: "gauge.with.needle", label: "Km", value: vehicle.odometerDisplay)
            Spacer()
            infoItem(
                icon: vehicle.transmissionType == .automatic ? "a.circle" : "m.circle",
                label: "Vites",
                value: vehicle.transmissionType?.displayName ?? "—"
            )
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            Text(value)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    // MARK: - Status Footer
    private var statusFooter: some View {
        HStack(spacing: AppSpacing.md) {
            // Yaklaşan iş
            if let title = upcomingReminderTitle {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                        .foregroundColor(statusColor)

                    Text(title)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Dosya tamlık skoru
            if let score = fileCompletenessScore {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption2)
                        .foregroundColor(scoreColor(score))

                    Text("%\(score)")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(scoreColor(score))
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private var statusIcon: String {
        switch upcomingReminderStatus {
        case .overdue: return "exclamationmark.triangle.fill"
        case .none, .active: return "bell.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "bell"
        }
    }

    private var statusColor: Color {
        switch upcomingReminderStatus {
        case .overdue: return AppColors.critical
        case .none, .active: return AppColors.warning
        case .completed: return AppColors.success
        case .archived: return AppColors.textTertiary
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return AppColors.warning }
        return AppColors.critical
    }
}

// MARK: - Preview
#Preview("VehicleCard — Normal") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            VehicleCard(
                vehicle: MockDataProvider.previewVehicle(),
                upcomingReminderTitle: "Trafik Sigortası — 5 gün gecikti",
                upcomingReminderStatus: .overdue,
                fileCompletenessScore: 65
            )
            VehicleCard(
                vehicle: MockDataProvider.previewVehicle2(),
                upcomingReminderTitle: "Muayene — 45 gün kaldı",
                upcomingReminderStatus: .active,
                fileCompletenessScore: 90
            )
        }
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
}

#Preview("VehicleCard — Dark Mode") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            VehicleCard(
                vehicle: MockDataProvider.previewVehicle(),
                upcomingReminderTitle: "Yağ Değişimi — Bugün",
                upcomingReminderStatus: .active,
                fileCompletenessScore: 75
            )
        }
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
}
