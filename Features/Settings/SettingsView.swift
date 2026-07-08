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
    @EnvironmentObject private var navigationRouter: AppNavigationRouter

    @State private var showPaywall = false
    @State private var paywallFeature: PaywallView.PaywallFeature = .secondVehicle
    @State private var showAssistantProfile = false
    // Yapay Zekâ (Bulut AI)
    @AppStorage(AIConsentStore.enabledKey) private var aiCloudEnabled = false
    @AppStorage(AIConsentStore.consentKey) private var aiConsentAccepted = false
    @State private var showAIConsent = false
    #if DEBUG
    @State private var aiTestResult: String?
    @State private var showAITestResult = false
    @State private var aiTestInFlight = false
    #endif
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var isExporting = false
    @State private var exportMessage: String?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
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

                // Akıllı Sürüş Asistanı
                assistantSection

                // Yapay Zekâ (Bulut AI) — sadece Pro kullanıcıya
                if paywallService.isPro {
                    aiSection
                }

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
                PaywallView(feature: paywallFeature)
            }
            .sheet(isPresented: $showAssistantProfile) {
                UsageProfileFlowView()
            }
            .sheet(isPresented: $showAIConsent) {
                AIConsentView(
                    onAccept: { aiConsentAccepted = true },
                    onDecline: { aiConsentAccepted = false; aiCloudEnabled = false }
                )
            }
            #if DEBUG
            .alert("AI Test", isPresented: $showAITestResult) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(aiTestResult ?? "")
            }
            #endif
            .confirmationDialog("Çıkış Yap", isPresented: $showSignOutConfirmation) {
                Button("Çıkış Yap", role: .destructive) {
                    Task { await signOut() }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Oturumun kapatılacak. Yerel verilerin (araçlar, masraflar, belgeler) silinmez. Topluluk özelliklerini kullanmak için tekrar giriş yapabilirsin.")
            }
            .confirmationDialog("Tüm Verileri Sil", isPresented: $showDeleteAllConfirmation) {
                Button("Tüm Verileri Sil", role: .destructive) { deleteAllData() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Tüm araçlar, hatırlatıcılar, masraflar, bakım kayıtları, belgeler ve raporlar kalıcı olarak silinir.")
            }
            .confirmationDialog("Hesabı ve verileri sil?", isPresented: $showDeleteAccountConfirmation) {
                Button("Hesabı Kalıcı Olarak Sil", role: .destructive) {
                    Task { await deleteAccountAndData() }
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm verilerin kalıcı olarak silinecek: araçlar, belgeler, topluluk gönderileri, yorumlar, beğeniler ve profil bilgilerin. Apple ile tekrar giriş yaptığında sıfırdan bir kullanıcı olarak başlarsın. Bu işlem GERİ ALINAMAZ.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
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
                    Label("Pro özellikleri keşfet", systemImage: "sparkles")
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

    // MARK: - Assistant Section
    private var assistantSection: some View {
        Section {
            Button {
                if paywallService.canUseAssistant {
                    showAssistantProfile = true
                } else {
                    paywallFeature = .assistant
                    showPaywall = true
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "steeringwheel")
                        .foregroundColor(AppColors.accentPrimary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Kullanım Profilim")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Akıllı Sürüş Asistanı önerilerini kişiselleştir.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    if paywallService.canUseAssistant {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        } header: {
            Text("Akıllı Sürüş Asistanı")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - AI Section (Bulut AI)
    private var aiSection: some View {
        Section {
            Toggle(isOn: $aiCloudEnabled) {
                Label("Bulut AI özellikleri", systemImage: "sparkles")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
            .onChange(of: aiCloudEnabled) { _, isOn in
                // Açılırken onay alınmamışsa tek seferlik onay ekranını göster.
                if isOn && !aiConsentAccepted {
                    showAIConsent = true
                }
            }

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
        } header: {
            Text("Yapay Zekâ")
        } footer: {
            Text("Açıkken; fiş okuma ve öneriler için metin, cihazından çıkmadan önce maskelenir (TC, plaka, IBAN, telefon gizlenir) ve yurt dışındaki bir AI sunucusuna gönderilir. Kapalıyken hiçbir metin gönderilmez; özellikler yerelde çalışır. İstediğin zaman kapatabilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
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
                    showSignOutConfirmation = true
                } label: {
                    Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                }

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

            // MARK: Insight Senaryoları (Karar 3.4)
            Menu {
                ForEach(DemoDataSeeder.InsightScenario.allCases) { scenario in
                    Button {
                        DemoDataSeeder.seedInsightScenario(scenario, context: modelContext)
                        // Garaj sekmesine yönlendir ve ayarları kapat
                        navigationRouter.selectedTab = .garage
                        dismiss()
                    } label: {
                        Label(scenario.displayName, systemImage: scenario.icon)
                    }
                }
            } label: {
                HStack {
                    Label("Insight Senaryoları", systemImage: "lightbulb")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .accessibilityLabel("Insight Senaryoları seç")

            // MARK: Mevcut demo seed
            Button {
                DemoDataSeeder.seed(context: modelContext)
            } label: {
                Label("Demo Verisi Yükle", systemImage: "wand.and.stars")
                    .foregroundColor(AppColors.accentPrimary)
            }

            // MARK: AI proxy uçtan uca test
            Button {
                runAITestRequest()
            } label: {
                HStack {
                    Label("AI: Uçtan Uca Test İsteği", systemImage: "sparkles")
                        .foregroundColor(AppColors.accentPrimary)
                    if aiTestInFlight {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(aiTestInFlight)
        } header: {
            Text("Geliştirici")
        } footer: {
            Text("Bu bölüm sadece DEBUG build’de görünür. Release/TestFlight build’de yer almaz. Senaryo seçilince tüm mevcut veri temizlenir.")
        }
        .listRowBackground(Color.appSurface)
    }
    #endif

    // MARK: - Actions
    #if DEBUG
    /// Dev hook: maskelenmiş örnek metinle proxy'ye uçtan uca istek atar.
    /// NOT: Alert yalnızca sonuç kesinleştiğinde açılır — iOS alert'leri açıldıktan
    /// sonra içeriğini güncelleyemez (UIAlertController sabittir), bu yüzden
    /// önce açıp sonra metni değiştirmek "sonsuza kadar bekliyor" görünümü verirdi.
    private func runAITestRequest() {
        aiTestInFlight = true
        let sample = PIIMaskingService.mask(
            "OPET AKARYAKIT\nTC 10000000146\nTarih: 15.03.2024\nTOPLAM: 1.079,50 TL"
        )
        Task {
            do {
                let receipt = try await AIProxyService.shared.parseReceipt(ocrText: sample)
                await MainActor.run {
                    aiTestResult = "OK · satıcı=\(receipt.vendor ?? "-") · toplam=\(receipt.total.map { String($0) } ?? "-")"
                    aiTestInFlight = false
                    showAITestResult = true
                }
            } catch let error as AIProxyError {
                await MainActor.run {
                    aiTestResult = "Hata (tipli): \(error)"
                    aiTestInFlight = false
                    showAITestResult = true
                }
            } catch {
                await MainActor.run {
                    aiTestResult = "Hata: \(error.localizedDescription)"
                    aiTestInFlight = false
                    showAITestResult = true
                }
            }
        }
    }
    #endif

    private func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func exportData() {
        isExporting = true
        exportMessage = nil
        exportURL = nil
        showShareSheet = false

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try DataExportService.export(context: modelContext)

                DispatchQueue.main.async {
                    isExporting = false
                    exportURL = result.url
                    exportMessage = "Veriler dışa aktarıldı. Paylaşım sayfası açılıyor..."
                    showShareSheet = true
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    exportMessage = "Dışa aktarma başarısız oldu. Lütfen tekrar dene."
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
            // Kullanım profili (Akıllı Sürüş Asistanı verisi)
            if let profiles = try? modelContext.fetch(FetchDescriptor<VehicleUsageProfile>()) {
                for p in profiles { modelContext.delete(p) }
            }
            // Maintenance plan cache dosyaları (disk'te JSON)
            MaintenancePlanCacheStore.deleteAll()

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

            // 5. Pro state'i sıfırla — sadece dev mode simülasyonunda; gerçek StoreKit
            // entitlement'ı asla ezilmemeli.
            if paywallService.isDevMode {
                paywallService.disableProForDev()
            }

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
        // Kullanım profili (Akıllı Sürüş Asistanı verisi) — modelden silinmezse
        // "Tüm Verileri Sil" çağrısından sonra bile sürüş alışkanlıkları UI'da
        // görünmeye devam eder.
        if let profiles = try? modelContext.fetch(FetchDescriptor<VehicleUsageProfile>()) {
            for p in profiles { modelContext.delete(p) }
        }

        // Maintenance plan cache dosyaları (caches/ altında JSON) — disk'te kalırsa
        // yeni eklenen araç için eski öneriler görüntülenebilir.
        MaintenancePlanCacheStore.deleteAll()

        // Belgeleri diskten temizle
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VehicleDocuments")
        try? FileManager.default.removeItem(at: docDir)

        // Araç fotoğraflarını temizle
        VehiclePhotoStorageService.shared.deleteAllPhotos()

        // Bildirimleri temizle
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        try? modelContext.save()

        // Dev mode'da Pro'yu sıfırla — gerçek StoreKit entitlement'ı asla ezilmemeli.
        if paywallService.isDevMode {
            paywallService.disableProForDev()
        }

        dismiss()
    }

    private func signOut() async {
        await communityAuth.signOut()
        dismiss()
    }
}

// MARK: - Preview
#Preview("Ayarlar") {
    SettingsView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(CommunityAuthService.shared)
}

#Preview("Ayarlar — Dark") {
    SettingsView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(CommunityAuthService.shared)
}
