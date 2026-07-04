import SwiftUI

// MARK: - AI Consent View
// Bulut AI özellikleri ilk kez açılırken gösterilen tek seferlik onay ekranı.
// Ne gönderiliyor (maskelenmiş metin), nereye (yurt dışı AI sunucusu), neden,
// ve istendiğinde kapatılabileceği açıkça belirtilir. Dark pattern yok.
struct AIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let onAccept: () -> Void
    let onDecline: () -> Void

    private let privacyURL = URL(string: "https://fatihdisci.github.io/arvia/privacy.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        bullet(icon: "text.redaction",
                               title: "Ne gönderilir?",
                               body: "Yalnızca maskelenmiş metin. TC kimlik, plaka, IBAN ve telefon gibi bilgiler cihazından çıkmadan önce otomatik olarak [MASKED] ile gizlenir.")
                        bullet(icon: "globe",
                               title: "Nereye gider?",
                               body: "Metin, isteği işleyen yurt dışındaki bir yapay zekâ sunucusuna iletilir. Kimliğinle eşleşen bir hesap oluşturulmaz; anonim bir cihaz kimliği kullanılır.")
                        bullet(icon: "sparkles",
                               title: "Neden?",
                               body: "Fiş okuma ve bakım önerileri gibi özellikleri daha isabetli hale getirmek için. Bu özellikler olmadan da uygulama tümüyle çalışır.")
                        bullet(icon: "switch.2",
                               title: "İstediğin zaman kapat",
                               body: "Ayarlar → Yapay Zekâ bölümünden bulut AI özelliklerini tek dokunuşla kapatabilirsin. Kapalıyken hiçbir metin gönderilmez.")
                    }

                    Link(destination: privacyURL) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Gizlilik Politikası")
                            Image(systemName: "arrow.up.forward").font(.caption)
                        }
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.accentPrimary)
                    }

                    actions
                }
                .padding(AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Yapay Zekâ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        onDecline()
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .interactiveDismissDisabled(true)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(AppColors.accentPrimary.opacity(0.08)).frame(width: 84, height: 84)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(AppColors.accentPrimary)
            }
            Text("Bulut AI özelliklerini aç")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Açmadan önce nasıl çalıştığını bil.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func bullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(body)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                onAccept()
                dismiss()
            } label: {
                Text("Kabul ediyorum, aç").frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)

            Button {
                onDecline()
                dismiss()
            } label: {
                Text("Şimdi değil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
        }
        .padding(.top, AppSpacing.sm)
    }
}

#Preview("AI Consent") {
    AIConsentView(onAccept: {}, onDecline: {})
}
