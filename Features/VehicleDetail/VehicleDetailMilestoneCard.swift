import SwiftUI

// MARK: - Vehicle Detail Milestone Card
// Araç yaşam çizgisindeki kritik milestone'lar için ayrıcalıklı kart.
// Karar 3.3 (Stratejik Kararlar Manifestosu). Mevcut timeline davranışı korunur;
// milestone event'ler bu kartla render edilir, regular event'ler mevcut sade liste hali kalır.
struct VehicleDetailMilestoneCard: View {
    enum MilestoneKind: String {
        case purchase       // araç satın alma
        case majorService   // ilk büyük bakım (parts_cost > 5000 veya major serviceType)
        case inspection     // ekspertiz raporu
        case saleFile       // satış dosyası
        case ownershipYear  // 5+ yıl sahiplik

        /// Her milestone için uygun icon.
        var defaultIcon: String {
            switch self {
            case .purchase: return "cart.fill"
            case .majorService: return "wrench.and.screwdriver.fill"
            case .inspection: return "checkmark.seal.fill"
            case .saleFile: return "doc.richtext.fill"
            case .ownershipYear: return "flag.checkered"
            }
        }

        /// Her milestone türü için accent rengi — design token üzerinden.
        var defaultAccent: Color {
            switch self {
            case .purchase: return AppColors.accentPrimary
            case .majorService: return AppColors.vehicle
            case .inspection: return AppColors.success
            case .saleFile: return AppColors.accentPrimary
            case .ownershipYear: return AppColors.warning
            }
        }

        /// Helper — milestone türünü Türkçe etiket olarak döner.
        var displayLabel: String {
            switch self {
            case .purchase: return "Satın Alma"
            case .majorService: return "Büyük Bakım"
            case .inspection: return "Ekspertiz"
            case .saleFile: return "Satış Dosyası"
            case .ownershipYear: return "Sahiplik Yıl Dönümü"
            }
        }
    }

    let kind: MilestoneKind
    let date: Date
    let title: String
    let subtitle: String?
    let icon: String
    let accent: Color

    private var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // İkon container — çevresinde accent ring
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 2)
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(kind.displayLabel)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(accent)
                    Spacer(minLength: 0)
                    Text(formattedDate)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .monospacedDigit()
                }

                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
.padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
            )
            .cardShadow()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(kind.displayLabel): \(title), \(formattedDate)")
        }
    }
