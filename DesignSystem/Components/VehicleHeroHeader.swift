import SwiftUI

// MARK: - Vehicle Hero Header
// Araç detay ekranında ana görsel çapa.
// Premium, sakin, Apple-native.
// Fotoğraf yoksa anlamlı bir placeholder gradyanı kullanır
// (tasarım anayasasında izin verilen tek gradyan kullanım yerlerinden biri).

struct VehicleHeroHeader: View {
    let vehicle: Vehicle
    @State private var appeared = false

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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.easeOut(duration: 0.32), value: appeared)
        .onAppear { appeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Photo Area
    private var photoArea: some View {
        ZStack(alignment: .bottomLeading) {
            if let photoFileName = vehicle.photoFileName,
               let image = VehiclePhotoStorageService.shared.loadPhoto(fileName: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: .infinity)
                    .clipped()
            } else {
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

            LinearGradient(
                colors: [.clear, .black.opacity(0.36)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text("Araç Dosyası")
                .font(AppTypography.captionMedium)
                .foregroundColor(.white.opacity(0.86))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 7)
                .background(Capsule().fill(.black.opacity(0.22)))
                .padding(AppSpacing.md)
        }
        .containerRelativeFrame(.vertical) { height, _ in height * 0.22 }
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(vehicle.nickname.isEmpty ? vehicle.fullName : vehicle.nickname)
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(vehicle.nickname.isEmpty ? vehicle.yearDisplay : vehicle.fullName)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(vehicle.plate.isEmpty ? "Plaka yok" : vehicle.plate)
                    .font(.custom("JetBrainsMono-SemiBold", size: 15))
                    .tracking(1.5)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppColors.backgroundSecondary))
            }

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
}
