import SwiftUI

// MARK: - Dossier Completeness Card
// "Dosya Tamlığı" — aracın dijital dosyasının ne kadar tam olduğunu gösterir.
// Mekanik sağlık skoru DEĞİLDİR. Satış dosyası hazırlığı veya bakım takip durumu gösterir.

struct DossierCompletenessCard: View {
    let score: Int // 0-100
    let criteriaMet: [String]
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

                if !criteriaMissing.isEmpty {
                    Text("Eksik: \(criteriaMissing.prefix(2).joined(separator: ", "))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("Aracının geçmişi iyi dokümante edilmiş.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.success)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
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
        .accessibilityLabel("Dosya skoru yüzde \(score). \(criteriaMissing.isEmpty ? "Tüm kriterler karşılandı." : "Eksikler: \(criteriaMissing.joined(separator: ", "))")")
    }

    private var scoreColor: Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return AppColors.warning }
        return AppColors.critical
    }
}

// MARK: - Preview

#Preview("Completeness — High") {
    DossierCompletenessCard(
        score: 85,
        criteriaMet: ["Marka/Model", "Yıl", "Km", "Vites", "Alış tarihi"],
        criteriaMissing: ["Ekspertiz raporu"]
    )
    .padding()
    .background(Color.appBackground)
}

#Preview("Completeness — Medium") {
    DossierCompletenessCard(
        score: 55,
        criteriaMet: ["Marka/Model", "Yıl"],
        criteriaMissing: ["Km", "Vites tipi", "Alış tarihi", "Ekspertiz"]
    )
    .padding()
    .background(Color.appBackground)
}

#Preview("Completeness — Dark") {
    DossierCompletenessCard(
        score: 70,
        criteriaMet: ["Marka/Model", "Yıl", "Km"],
        criteriaMissing: ["Alış tarihi", "Ekspertiz"]
    )
    .padding()
    .background(Color.appBackground)
}
