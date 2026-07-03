import SwiftUI

// MARK: - Dossier Completeness Card
// "Dosya Tamlığı" — aracın dijital dosyasının ne kadar tam olduğunu gösterir.
// Mekanik sağlık skoru DEĞİLDİR. Satış dosyası hazırlığı veya bakım takip durumu gösterir.
//
// Skor aralıklarına göre mesaj:
// - 0-29%  : Başlangıç — dosyayı oluşturmaya başladın, keşfedilecek çok şey var
// - 30-59% : Gelişmekte — iyi gidiyorsun, birkaç bilgi daha zenginleştirebilir
// - 60-79% : İleri — dosyan iyi durumda, son detaylar kaldı
// - 80-100%: Tam — aracının geçmişi kapsamlı biçimde kayıtlı
//
// Tüm aralıklarda olumlu/teşvik edici ton — "kötü/yetersiz" gibi kelime yok.

struct DossierCompletenessCard: View {
    let score: Int // 0-100
    let criteriaMissing: [String]

    @State private var animatedScore: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 5)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: animatedScore)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("%\(score)")
                        .font(AppTypography.cardTitleSmall)
                        .foregroundColor(scoreColor)
                    Text("tam")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Dosya Skoru")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(scoreMessage)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !criteriaMissing.isEmpty {
                    Text("Şunları ekleyebilirsin: \(criteriaMissing.prefix(2).joined(separator: ", "))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedScore = CGFloat(score) / 100.0
                }
            } else {
                animatedScore = CGFloat(score) / 100.0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Skor aralığına göre mesaj — yumuşak ve teşvik edici

    private var scoreMessage: String {
        switch score {
        case 0..<30:
            return "Aracının dijital dosyasını oluşturmaya başladın. Keşfedilecek çok şey var."
        case 30..<60:
            return "İyi gidiyorsun. Birkaç bilgi daha dosyanı zenginleştirebilir."
        case 60..<80:
            return "Aracının dosyası iyi durumda. Son detaylar kaldı."
        default:
            return "Aracının geçmişi kapsamlı biçimde kayıtlı."
        }
    }

    private var scoreColor: Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return AppColors.warning }
        return AppColors.critical
    }

    private var accessibilityLabel: String {
        var parts = ["Dosya skoru yüzde \(score). \(scoreMessage)"]
        if !criteriaMissing.isEmpty {
            parts.append("Şunları ekleyebilirsin: \(criteriaMissing.prefix(2).joined(separator: ", "))")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Preview

#Preview("Completeness — 0%") {
    DossierCompletenessCard(score: 0, criteriaMissing: ["Marka", "Model", "Yıl", "Km"])
        .padding()
        .background(Color.appBackground)
}

#Preview("Completeness — 25%") {
    DossierCompletenessCard(score: 25, criteriaMissing: ["Marka", "Yıl", "Km"])
        .padding()
        .background(Color.appBackground)
}

#Preview("Completeness — 45%") {
    DossierCompletenessCard(score: 45, criteriaMissing: ["Belge", "Hatırlatıcı", "Bakım"])
        .padding()
        .background(Color.appBackground)
}

#Preview("Completeness — 65%") {
    DossierCompletenessCard(score: 65, criteriaMissing: ["Ekspertiz"])
        .padding()
        .background(Color.appBackground)
}

#Preview("Completeness — 85%") {
    DossierCompletenessCard(score: 85, criteriaMissing: [])
        .padding()
        .background(Color.appBackground)
}

#Preview("Completeness — 100%") {
    DossierCompletenessCard(score: 100, criteriaMissing: [])
        .padding()
        .background(Color.appBackground)
}