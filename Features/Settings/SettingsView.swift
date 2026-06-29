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
    @EnvironmentObject private var communityAuth: CommunityAuthService

    @State private var showPaywall = false
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var isExporting = false
    @State private var exportMessage: String?
    // Privacy & Terms URL'leri — GitHub Pages canlı URL'leri
    private let privacyURL = URL(string: "https://fatihdisci.github.io/arvia/privacy.html")!
    private let termsURL = URL(string: "https://fatihdisci.github.io/arvia/terms.html")!
    private let supportURL = URL(string: "https://fatihdisci.github.io/arvia/support.html")!
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let supportEmail = "behavest@proton.me"

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

                // Geliştirici (sadece DEBUG)
                #if DEBUG
                developerSection
                #endif
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: .secondVehicle)
            }
            .confirmationDialog("Tüm Verileri Sil", isPresented: $showDeleteAllConfirmation) {
                Button("Tüm Verileri Sil", role: .destructive) { deleteAllData() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Tüm araçlar, hatırlatıcılar, masraflar, bakım kayıtları, belgeler ve raporlar kalıcı olarak silinir.")
            }
            .confirmationDialog("Hesabı ve verileri sil?", isPresented: $showDeleteAccountConfirmation) {
                Button("Sil", role: .destructive) {
                    Task { await deleteAccountAndData() }
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Bu işlem yerel araç kayıtlarını, belgeleri ve topluluk profil bilgilerini silebilir. Bu işlem geri alınamaz.")
            }
        }
    }

    // MARK: - Pro Section
    private var proSection: some View {
        Section {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: paywallService.isPro ? "crown.fill" : "checkmark.seal.fill")
                    .foregroundColor(paywallService.isPro ? AppColors.warning : AppColors.success)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(paywallService.isPro ? "Arvia Pro" : "Ücretsiz Plan")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(paywallService.isPro
                         ? "Birden fazla aracı aynı garajda yönetebilirsin."
                         : "Tek araç için tüm temel özellikler açık. Arvia ücretsiz ve reklamsızdır.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if !paywallService.isPro {
                Button {
                    showPaywall = true
                } label: {
                    Label("Birden fazla araç eklemek için Pro’ya geç", systemImage: "car.2")
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
            Text("Plan")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Notification Preferences (Retention)
    @AppStorage("notif_pref_important_dates") private var prefImportantDates = true
    @AppStorage("notif_pref_km_update") private var prefKmUpdate = true
    @AppStorage("notif_pref_km_freq") private var prefKmFreq = RetentionNotificationService.KmUpdateFrequency.quarterly.rawValue
    @AppStorage("notif_pref_monthly_summary") private var prefMonthlySummary = true
    @AppStorage("notif_pref_doc_complete") private var prefDocComplete = true
    @AppStorage("notif_pref_seasonal") private var prefSeasonal = true
    @AppStorage("notif_pref_sale_file") private var prefSaleFile = false

    // MARK: - Notification Section
    private var notificationSection: some View {
        Section {
            // Sistem bildirim ayarları
            Button {
                openSystemNotificationSettings()
            } label: {
                HStack {
                    Label("Sistem Bildirim İzni", systemImage: "bell.badge")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            // Önemli Tarihler
            Toggle(isOn: $prefImportantDates) {
                Label("Önemli Tarihler", systemImage: "calendar.badge.exclamationmark")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
            .onChange(of: prefImportantDates) { _, _ in
                RetentionNotificationService.shared.isImportantDatesEnabled = prefImportantDates
                Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
            }

            // Kilometre Güncelleme
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Toggle(isOn: $prefKmUpdate) {
                    Label("Kilometre Güncelleme", systemImage: "gauge.with.needle")
                        .font(AppTypography.body)
                }
                .tint(AppColors.accentPrimary)
                .onChange(of: prefKmUpdate) { _, _ in
                    RetentionNotificationService.shared.isKmUpdateEnabled = prefKmUpdate
                    Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
                }

                if prefKmUpdate {
                    Picker("Sıklık", selection: $prefKmFreq) {
                        ForEach(RetentionNotificationService.KmUpdateFrequency.allCases, id: \.rawValue) { freq in
                            Text(freq.displayName).tag(freq.rawValue)
                        }
                    }
                    .font(AppTypography.secondary)
                    .onChange(of: prefKmFreq) { _, newValue in
                        RetentionNotificationService.shared.kmUpdateFrequency = RetentionNotificationService.KmUpdateFrequency(rawValue: newValue) ?? .quarterly
                        Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
                    }
                }
            }

            // Aylık Özet
            Toggle(isOn: $prefMonthlySummary) {
                Label("Aylık Özet", systemImage: "chart.bar.doc.horizontal")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
            .onChange(of: prefMonthlySummary) { _, _ in
                RetentionNotificationService.shared.isMonthlySummaryEnabled = prefMonthlySummary
                Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
            }

            // Dosya Tamlığı
            Toggle(isOn: $prefDocComplete) {
                Label("Dosya Tamlığı", systemImage: "doc.text.magnifyingglass")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
            .onChange(of: prefDocComplete) { _, _ in
                RetentionNotificationService.shared.isDocumentCompletenessEnabled = prefDocComplete
                Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
            }

            // Mevsimsel Bakım
            Toggle(isOn: $prefSeasonal) {
                Label("Mevsimsel Bakım", systemImage: "leaf")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
            .onChange(of: prefSeasonal) { _, _ in
                RetentionNotificationService.shared.isSeasonalEnabled = prefSeasonal
                Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
            }

            // Satış Dosyası Hatırlatması
            Toggle(isOn: $prefSaleFile) {
                Label("Satış Dosyası Hatırlatması", systemImage: "doc.richtext")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
            .onChange(of: prefSaleFile) { _, _ in
                RetentionNotificationService.shared.isSaleFileReminderEnabled = prefSaleFile
                Task { await NotificationRefreshService.refreshAfterSettingsChange(context: modelContext) }
            }
        } header: {
            Text("Bildirim Tercihleri")
        } footer: {
            Text("Reklam bildirimi göndermiyoruz. Tüm bildirimleri buradan kapatabilirsin. Plaka gibi hassas bilgiler bildirim içeriğinde gösterilmez. Sessiz saatler (21:00–09:00) arası bildirim gönderilmez.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
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
                    Label("Verileri Dışa Aktar (JSON)", systemImage: "square.and.arrow.up")
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

            if communityAuth.isAuthenticated {
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Label("Hesabı ve Verileri Sil", systemImage: "person.crop.circle.badge.xmark")
                        if isDeletingAccount {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeletingAccount)

                if let error = deleteAccountError {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.critical)
                }
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

            Link(destination: eulaURL) {
                HStack {
                    Label("Apple Standart EULA", systemImage: "checkmark.seal")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Link(destination: supportURL) {
                HStack {
                    Label("Destek", systemImage: "questionmark.circle")
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
                Text("\(AppBrand.appName) bir resmi kurum uygulaması değildir. TÜVTÜRK, Gelir İdaresi Başkanlığı, sigorta şirketleri veya herhangi bir kamu kurumuyla bağlantısı yoktur. Hatırlatıcılar yalnızca bilgilendirme amaçlıdır.")
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

    // MARK: - Developer Section (DEBUG only)
    #if DEBUG
    private var developerSection: some View {
        Section {
            Button {
                paywallService.enableProForDev()
            } label: {
                Label("Dev: Pro’yu Aç", systemImage: "crown.fill")
                    .foregroundColor(AppColors.accentPrimary)
            }

            Button {
                paywallService.disableProForDev()
            } label: {
                Label("Dev: Free’ye Dön", systemImage: "arrow.uturn.backward")
                    .foregroundColor(AppColors.textSecondary)
            }
        } header: {
            Text("Geliştirici")
        } footer: {
            Text("Bu bölüm sadece DEBUG build’de görünür. Release/TestFlight build’de yer almaz.")
        }
        .listRowBackground(Color.appSurface)
    }
    #endif

    // MARK: - Actions
    private func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func exportData() {
        isExporting = true
        // Gerçek JSON export — araç, hatırlatıcı, masraf, bakım, belge ve ekspertiz verileri.
        DispatchQueue.global(qos: .userInitiated).async {
            // Fetch tüm verileri ana context'te yap
            DispatchQueue.main.async {
                let vehicles = (try? modelContext.fetch(FetchDescriptor<Vehicle>())) ?? []
                let reminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
                let expenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
                let services = (try? modelContext.fetch(FetchDescriptor<ServiceRecord>())) ?? []
                let documents = (try? modelContext.fetch(FetchDescriptor<VehicleDocument>())) ?? []
                let inspections = (try? modelContext.fetch(FetchDescriptor<InspectionReport>())) ?? []
                let saleFiles = (try? modelContext.fetch(FetchDescriptor<SaleFile>())) ?? []

                var export: [String: Any] = [:]

                export["vehicles"] = vehicles.map { v in
                    [
                        "id": v.id.uuidString,
                        "plate": v.plate,
                        "brand": v.brand,
                        "model": v.model,
                        "year": v.year as Any,
                        "currentOdometer": v.currentOdometer,
                        "fuelType": v.fuelTypeRaw,
                        "usageType": v.usageTypeRaw,
                        "createdAt": v.createdAt.ISO8601Format(),
                        "archivedAt": v.archivedAt?.ISO8601Format() as Any,
                    ] as [String: Any]
                }

                export["reminders"] = reminders.map { r in
                    [
                        "id": r.id.uuidString,
                        "vehicleId": r.vehicleId.uuidString,
                        "title": r.title,
                        "type": r.typeRaw,
                        "dueDate": r.dueDate?.ISO8601Format() as Any,
                        "dueOdometer": r.dueOdometer as Any,
                        "repeatRule": r.repeatRuleRaw as Any,
                        "priority": r.priorityRaw,
                        "status": r.statusRaw,
                        "completedAt": r.completedAt?.ISO8601Format() as Any,
                        "createdAt": r.createdAt.ISO8601Format(),
                    ] as [String: Any]
                }

                export["expenses"] = expenses.map { e in
                    [
                        "id": e.id.uuidString,
                        "vehicleId": e.vehicleId.uuidString,
                        "category": e.categoryRaw,
                        "amount": e.amount,
                        "currency": e.currencyCode,
                        "date": e.date.ISO8601Format(),
                        "odometer": e.odometer as Any,
                        "vendorName": e.vendorName as Any,
                        "note": e.note,
                    ] as [String: Any]
                }

                export["serviceRecords"] = services.map { s in
                    [
                        "id": s.id.uuidString,
                        "vehicleId": s.vehicleId.uuidString,
                        "serviceType": s.serviceTypeRaw,
                        "date": s.date.ISO8601Format(),
                        "odometer": s.odometer as Any,
                        "vendorName": s.vendorName as Any,
                        "laborCost": s.laborCost as Any,
                        "partsCost": s.partsCost as Any,
                        "totalCost": s.totalCost as Any,
                        "oilType": s.oilType as Any,
                        "notes": s.notes,
                    ] as [String: Any]
                }

                export["documents"] = documents.map { d in
                    [
                        "id": d.id.uuidString,
                        "vehicleId": d.vehicleId.uuidString,
                        "type": d.typeRaw,
                        "title": d.title,
                        "originalFileName": d.originalFileName as Any,
                        "issueDate": d.issueDate?.ISO8601Format() as Any,
                        "expiryDate": d.expiryDate?.ISO8601Format() as Any,
                        "includeInSaleFile": d.includeInSaleFile,
                    ] as [String: Any]
                }

                export["inspectionReports"] = inspections.map { i in
                    [
                        "id": i.id.uuidString,
                        "vehicleId": i.vehicleId.uuidString,
                        "providerName": i.providerName,
                        "reportDate": i.reportDate.ISO8601Format(),
                        "odometer": i.odometer as Any,
                        "summary": i.summary,
                        "includeInSaleFile": i.includeInSaleFile,
                    ] as [String: Any]
                }

                export["saleFiles"] = saleFiles.map { sf in
                    [
                        "id": sf.id.uuidString,
                        "vehicleId": sf.vehicleId.uuidString,
                        "title": sf.title,
                        "createdAt": sf.createdAt.ISO8601Format(),
                        "hasPDF": sf.generatedPDFFileName != nil,
                    ] as [String: Any]
                }

                export["exportDate"] = Date().ISO8601Format()
                export["appVersion"] = AppEnvironment.appVersion
                export["vehicleCount"] = vehicles.count
                export["reminderCount"] = reminders.count
                export["expenseCount"] = expenses.count
                export["serviceCount"] = services.count
                export["saleFileCount"] = saleFiles.count
                export["note"] = "Belge dosyaları (PDF/fotoğraf) JSON içine dahil edilmez."

                if let jsonData = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted) {

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("arvia-export-\(Date().ISO8601Format().prefix(10)).json")
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

    private func deleteAccountAndData() async {
        isDeletingAccount = true
        deleteAccountError = nil

        do {
            // 1. Local SwiftData temizliği
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

            // 2. Local belge dosyalarını ve araç fotoğraflarını fiziksel olarak temizle
            DocumentStorageService.shared.deleteAllFiles()
            VehiclePhotoStorageService.shared.deleteAllPhotos()

            // 3. Bildirimleri temizle
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

            try modelContext.save()

            // 4. Topluluk profilini anonimleştir ve çıkış yap
            if communityAuth.isAuthenticated {
                try await communityAuth.deleteAccount()
            }

            // 5. Pro state'i sıfırla
            paywallService.disableProForDev()

            dismiss()
        } catch {
            deleteAccountError = "Silme işlemi başarısız oldu: \(error.localizedDescription)"
        }
        isDeletingAccount = false
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

        // Araç fotoğraflarını temizle
        VehiclePhotoStorageService.shared.deleteAllPhotos()

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
        .environmentObject(CommunityAuthService.shared)
}
