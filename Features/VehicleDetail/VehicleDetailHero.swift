import SwiftUI

// MARK: - Detail Hero
struct VehicleDetailHero: View {
    let vehicle: Vehicle
    let fileScore: Int

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            detailHeroPhotoCard
            detailHeroInfoCard
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vehicle.plate), \(vehicle.fullName), \(vehicle.odometerDisplay)")
    }

    private var detailHeroPhotoCard: some View {
        ZStack {
            if let photoFileName = vehicle.photoFileName,
               let image = VehiclePhotoStorageService.shared.loadPhoto(fileName: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            AppColors.vehicle.opacity(0.92),
                            AppColors.vehicle.opacity(0.7),
                            AppColors.accentPrimary.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: vehicle.vehicleType.heroSymbol)
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.32))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous))
        .elevatedShadow()
    }

    private var detailHeroInfoCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Satır 1: kimlik (fullName/nickname + plaka yan yana)
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.nickname.isEmpty ? vehicle.fullName : vehicle.nickname)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if !vehicle.nickname.isEmpty {
                        Text(vehicle.fullName)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Text(vehicle.yearDisplay)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                        Text("•")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Text(vehicle.vehicleType.displayName)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: AppSpacing.sm)

                detailPlateBadge
            }

            Divider()

            // Satır 2: metrics
            HStack(spacing: AppSpacing.xs) {
                detailMetricBadge(icon: "gauge.with.needle", text: vehicle.odometerDisplay)
                detailMetricBadge(icon: "fuelpump", text: vehicle.fuelType.displayName)
                if let transmission = vehicle.transmissionType {
                    detailMetricBadge(
                        icon: transmission == .automatic ? "a.circle" : "m.circle",
                        text: transmission.displayName
                    )
                }
                Spacer(minLength: 0)
            }

            // Satır 3: dosya tamlığı
            detailDossierBadge
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private var detailPlateBadge: some View {
        Text(vehicle.plate.isEmpty ? "Plaka yok" : vehicle.plate)
            .font(.custom("JetBrainsMono-SemiBold", size: 15))
            .tracking(1.5)
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColors.backgroundSecondary.opacity(0.72)))
    }

    private var detailYearTypeBlock: some View {
        HStack(spacing: 3) {
            Text(vehicle.yearDisplay)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("•")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            Text(vehicle.vehicleType.displayName)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private var detailDossierBadge: some View {
        let barColor = fileScore >= 80 ? AppColors.success : AppColors.accentPrimary
        return HStack(spacing: AppSpacing.xs) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
                .foregroundColor(barColor)
            Text("Dosya Skoru")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            Spacer(minLength: 0)
            Text("%\(fileScore)")
                .font(AppTypography.labelMono)
                .foregroundColor(barColor)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(barColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .stroke(barColor.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityLabel("Dosya skoru yüzde \(fileScore)")
    }

    private func detailMetricBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.medium))
            Text(text)
                .font(AppTypography.captionMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs + 2)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(AppColors.backgroundSecondary.opacity(0.68))
        )
    }
}
