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
            // Yarım daire takometre-yayı (anayasaya uygun)
            ZStack {
                // Arka plan yayı (silik guide)
                halfCircleArc(progress: 1.0)
                    .stroke(scoreColor.opacity(0.15), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)

                // Skor yayı
                halfCircleArc(progress: animatedScore)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)

                VStack(spacing: 0) {
                    Text("%\(score)")
                        .font(.custom("JetBrainsMono-SemiBold", size: 16))
                        .foregroundColor(scoreColor)
                        .monospacedDigit()
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
        // 80+ yeşil, 30+ turkuaz (tek enerji vurgusu), <30 amber.
        // critical (#FF2D3C) yalnızca form hatası/gecikmiş reminder/destructive buton içindir.
        if score >= 80 { return AppColors.success }
        if score >= 30 { return AppColors.accentPrimary }
        return AppColors.warning
    }

    // MARK: - Half-Circle Arc (takometre-yayı)
    // 01_DESIGN.md Madde 3: tam daire progress ring yasak.
    // Yarım daire: alttan açık, soldan sağa dolan 180° yay.
    private func halfCircleArc(progress: CGFloat) -> Path {
        var path = Path()
        let radius: CGFloat = 27
        let center = CGPoint(x: 32, y: 32)
        // Soldan (180°) sağa (0°) doğru saat yönünde ilerler
        let endAngle = 180.0 - (180.0 * Double(progress))
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(endAngle),
            clockwise: true
        )
        return path
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