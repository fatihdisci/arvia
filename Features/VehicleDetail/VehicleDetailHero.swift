import SwiftUI

// MARK: - Detail Hero
struct VehicleDetailHero: View {
    let vehicle: Vehicle

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
        // İmza motif: köşe ayraç/reticle — aracın görsel kimlik alanı
        .reticleCorners()
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

            // Satır 2: hero metric (km) + yan bilgiler (yakıt, vites)
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.currentOdometer.formatted())
                        .font(AppTypography.heroMetric)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("km")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textTertiary)
                }
                .accessibilityLabel("\(vehicle.currentOdometer.formatted()) kilometre")

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: 4) {
                        Image(systemName: "fuelpump")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                        Text(vehicle.fuelType.displayName)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let transmission = vehicle.transmissionType {
                        HStack(spacing: 4) {
                            Image(systemName: transmission == .automatic ? "a.circle" : "m.circle")
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                            Text(transmission.displayName)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
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
            .font(.custom("JetBrainsMono-SemiBold", size: 17))
            .tracking(1.5)
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(AppColors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
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
}
