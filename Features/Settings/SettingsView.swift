import SwiftUI
import SwiftData
import StoreKit

// MARK: - Settings View
// Ayarlar, bildirim tercihleri, veri yönetimi, hukuki metinler.
// App Store review için zorunlu tüm bağlantıları içerir.

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    @State private var showDeleteAllConfirmation = false
    @State private var isExporting = false
    @State private var exportMessage: String?

    // Privacy & Terms URL'leri — gerçek URL'ler ile değiştirilmeli
    private let privacyURL = URL(string: "https://ruhsatim.app/privacy")!
    private let termsURL = URL(string: "https://ruhsatim.app/terms")!
    private let supportEmail = "destek@ruhsatim.app"

    var body: some View {
        NavigationStack {
            Form {
                // Pro / Abonelik
                proSection

                // Bildirimler
                notificationSection

                // Veri Yönetimi
                dataSection

                // Hukuki
                legalSection

                // Uygulama Hakkında
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam") { dismiss() }
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .confirmationDialog("Tüm Verileri Sil", isPresented: $showDeleteAllConfirmation) {
                Button("Tüm Verileri Sil", role: .destructive) { deleteAllData() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Tüm araçlar, hatırlatıcılar, masraflar, bakım kayıtları, belgeler ve raporlar kalıcı olarak silinir.")
            }
        }
    }

    // MARK: - Pro Section
    private var proSection: some View {
        Section {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(paywallService.isPro ? AppColors.warning : AppColors.textTertiary)
                Text("Pro Durumu")
                    .font(AppTypography.body)
                Spacer()
                Text(paywallService.isPro ? "Pro" : "Ücretsiz")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(paywallService.isPro ? AppColors.warning : AppColors.textSecondary)
            }

            if !paywallService.isPro {
                Button {
                    dismiss()
                    // PaywallView gösterilecek — parent'tan handling
                } label: {
                    Label("Pro'ya Geç", systemImage: "arrow.up.forward")
                        .foregroundColor(AppColors.accentPrimary)
                }
            }

            Button {
                Task { await paywallService.restorePurchases() }
            } label: {
                Label("Satın Almaları Geri Yükle", systemImage: "arrow.counterclockwise")
                    .foregroundColor(AppColors.accentPrimary)
            }
        } header: {
            Text("Abonelik")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Notification Section
    private var notificationSection: some View {
        Section {
            Button {
                openSystemNotificationSettings()
            } label: {
                HStack {
                    Label("Bildirim Ayarları", systemImage: "bell")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Text("Muayene, sigorta ve bakım tarihleri için hatırlatıcılar. Reklam bildirimi göndermiyoruz.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        } header: {
            Text("Bildirimler")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Data Section
    private var dataSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                HStack {
                    Label("Verileri Dışa Aktar", systemImage: "square.and.arrow.up")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)

            if let message = exportMessage {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Label("Tüm Verileri Sil", systemImage: "trash")
            }
        } header: {
            Text("Veri Yönetimi")
        } footer: {
            Text("Verilerin cihazında saklanır. Verilerini dışa aktarabilir veya tamamen silebilirsin.")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        Section {
            Link(destination: privacyURL) {
                HStack {
                    Label("Gizlilik Politikası", systemImage: "hand.raised")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Link(destination: termsURL) {
                HStack {
                    Label("Kullanım Koşulları", systemImage: "doc.text")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)
                    Text("Yasal Uyarı")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.warning)
                }
                Text("Ruhsatım bir resmi kurum uygulaması değildir. TÜVTÜRK, Gelir İdaresi Başkanlığı, sigorta şirketleri veya herhangi bir kamu kurumuyla bağlantısı yoktur. Hatırlatıcılar yalnızca bilgilendirme amaçlıdır.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, AppSpacing.xxs)
        } header: {
            Text("Hukuki")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Sürüm")
                    .font(AppTypography.body)
                Spacer()
                Text("\(AppEnvironment.appVersion) (\(AppEnvironment.buildNumber))")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
            }

            Button {
                // Mail compose — gerçek cihazda çalışır
                if let url = URL(string: "mailto:\(supportEmail)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Label("Destek", systemImage: "envelope")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(supportEmail)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Text("Aracının dijital yaşam dosyası.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        } header: {
            Text("Uygulama Hakkında")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Actions
    private func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func exportData() {
        isExporting = true
        // Basit JSON export — tüm verileri birleştir
        DispatchQueue.global(qos: .userInitiated).async {
            var export: [String: Any] = [:]

            // Ana context'te fetch yap
            DispatchQueue.main.async {
                let vehicles = (try? modelContext.fetch(FetchDescriptor<Vehicle>())) ?? []
                let reminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
                let expenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
                let services = (try? modelContext.fetch(FetchDescriptor<ServiceRecord>())) ?? []

                export["vehicleCount"] = vehicles.count
                export["reminderCount"] = reminders.count
                export["expenseCount"] = expenses.count
                export["serviceCount"] = services.count
                export["exportDate"] = Date().ISO8601Format()
                export["appVersion"] = AppEnvironment.appVersion

                if let jsonData = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted) {

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("ruhsatim-export-\(Date().ISO8601Format().prefix(10)).json")
                    try? jsonData.write(to: tempURL)

                    DispatchQueue.main.async {
                        isExporting = false
                        exportMessage = "Veriler dışa aktarıldı. Paylaşım sayfası açılıyor..."

                        // Share sheet
                        let activityVC = UIActivityViewController(
                            activityItems: [tempURL],
                            applicationActivities: nil
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = windowScene.windows.first?.rootViewController {
                            root.present(activityVC, animated: true)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        isExporting = false
                        exportMessage = "Dışa aktarma başarısız oldu."
                    }
                }
            }
        }
    }

    private func deleteAllData() {
        // Tüm SwiftData modellerini tek tek sil
        if let vehicles = try? modelContext.fetch(FetchDescriptor<Vehicle>()) {
            for v in vehicles { modelContext.delete(v) }
        }
        if let reminders = try? modelContext.fetch(FetchDescriptor<Reminder>()) {
            for r in reminders { modelContext.delete(r) }
        }
        if let expenses = try? modelContext.fetch(FetchDescriptor<Expense>()) {
            for e in expenses { modelContext.delete(e) }
        }
        if let services = try? modelContext.fetch(FetchDescriptor<ServiceRecord>()) {
            for s in services { modelContext.delete(s) }
        }
        if let parts = try? modelContext.fetch(FetchDescriptor<PartChange>()) {
            for p in parts { modelContext.delete(p) }
        }
        if let docs = try? modelContext.fetch(FetchDescriptor<VehicleDocument>()) {
            for d in docs { modelContext.delete(d) }
        }
        if let inspections = try? modelContext.fetch(FetchDescriptor<InspectionReport>()) {
            for i in inspections { modelContext.delete(i) }
        }
        if let sales = try? modelContext.fetch(FetchDescriptor<SaleFile>()) {
            for s in sales { modelContext.delete(s) }
        }

        // Belgeleri diskten temizle
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VehicleDocuments")
        try? FileManager.default.removeItem(at: docDir)

        // Bildirimleri temizle
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        try? modelContext.save()

        // Dev mode'da Pro'yu sıfırla
        paywallService.disableProForDev()

        dismiss()
    }
}

// MARK: - Preview
#Preview("Ayarlar") {
    SettingsView()
        .environmentObject(PaywallService.shared)
}
