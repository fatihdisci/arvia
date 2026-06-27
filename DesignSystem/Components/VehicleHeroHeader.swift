import SwiftUI

// MARK: - Vehicle Hero Header
// Araç detay ekranında ana görsel çapa.
// Premium, sakin, Apple-native.
// Fotoğraf yoksa anlamlı bir placeholder gradyanı kullanır
// (tasarım anayasasında izin verilen tek gradyan kullanım yerlerinden biri).

struct VehicleHeroHeader: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(spacing: 0) {
            // Fotoğraf / placeholder alanı
            photoArea

            // Araç bilgileri
            infoArea
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.heroCard)
                .fill(Color.appSurface)
        )
        .elevatedShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Photo Area
    private var photoArea: some View {
        ZStack {
            // Placeholder gradyan (tasarım anayasası izinli kullanım)
            LinearGradient(
                colors: [
                    AppColors.vehicle,
                    AppColors.vehicle.opacity(0.6),
                    AppColors.accentPrimary.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Araç / motosiklet simgesi
            Image(systemName: vehicle.vehicleType.heroSymbol)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(height: 180)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: AppRadius.heroCard,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppRadius.heroCard
            )
        )
    }

    // MARK: - Info Area
    private var infoArea: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Plaka — ana görsel çapa
            Text(vehicle.plate.isEmpty ? "—" : vehicle.plate)
                .plateTextStyle()
                .foregroundColor(AppColors.textPrimary)

            // Marka + Model + Yıl
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(vehicle.fullName)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)

                if let year = vehicle.year {
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    Text(String(year))
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Km + Yakıt + Vites badge'leri
            HStack(spacing: AppSpacing.sm) {
                infoBadge(icon: "gauge.with.needle", text: vehicle.odometerDisplay)

                infoBadge(icon: "fuelpump", text: vehicle.fuelType.displayName)

                if let transmission = vehicle.transmissionType {
                    infoBadge(
                        icon: transmission == .automatic ? "a.circle" : "m.circle",
                        text: transmission.displayName
                    )
                }

                if vehicle.usageType != .personal {
                    infoBadge(icon: "briefcase", text: vehicle.usageType.displayName)
                }
            }

            // Nickname
            if !vehicle.nickname.isEmpty {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.accentPrimary)
                    Text(vehicle.nickname)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.accentPrimary)
                }
                .padding(.top, AppSpacing.xxs)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Badge
    private func infoBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(AppTypography.captionMedium)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(AppColors.backgroundSecondary)
        )
    }

    private var accessibilityText: String {
        "\(vehicle.plate), \(vehicle.fullName), \(vehicle.odometerDisplay)"
    }
}

// MARK: - Preview
#Preview("Hero Header — Dolu") {
    ScrollView {
        VehicleHeroHeader(
            vehicle: MockDataProvider.previewVehicle()
        )
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
}

#Preview("Hero Header — Minimal") {
    ScrollView {
        VehicleHeroHeader(
            vehicle: Vehicle(
                plate: "34 TEST 01",
                brand: "Honda",
                model: "",
                fuelType: .hybrid,
                currentOdometer: 12345
            )
        )
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
}

#Preview("Hero Header — Dark Mode") {
    ScrollView {
        VehicleHeroHeader(
            vehicle: MockDataProvider.previewVehicle()
        )
        .padding(.vertical, AppSpacing.lg)
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
