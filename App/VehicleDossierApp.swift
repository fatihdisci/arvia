import SwiftUI
import SwiftData
import OSLog

// MARK: - App Entry Point
// @main uygulama girişi.
// SwiftData container yapılandırması ve root view.

@main
struct VehicleDossierApp: App {
    private static let logger = Logger(subsystem: "com.ruhsatim.app", category: "DataMigration")
    let modelContainer: ModelContainer
    let startupWarning: String?
    @StateObject private var paywallService = PaywallService.shared
    @StateObject private var navigationRouter = AppNavigationRouter.shared
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    /// Onboarding sonrası açılacak sheet tipi — her durumda tek tip wizard kullanılır.
    @State private var postOnboardingSheet: PostOnboardingSheet?
    @State private var showStartupWarning = false
    private enum PostOnboardingSheet: Identifiable {
        case wizard
        var id: String { "wizard" }
    }

    init() {
        Self.configureAppearance()
        AIClientID.removeLegacyIdentifier()
        let schema = Schema([
                Vehicle.self,
                Reminder.self,
                Expense.self,
                ServiceRecord.self,
                PartChange.self,
                VehicleDocument.self,
                InspectionReport.self,
                SaleFile.self,
                Receipt.self,
                VehicleUsageProfile.self,
            ])
        let cloudConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.ruhsatim.app")
        )
        do {
            // CloudKit private database sync — yalnızca feature flag açıkken devreye girer.
            // Flag kapalıyken `.none` ile bugünkü davranış birebir korunur (sadece yerel).
            // Flag'i açmadan ÖNCE Xcode'da iCloud/CloudKit capability'si ve aşağıdaki
            // container kimliği eklenmelidir; aksi halde container init eder ve fatalError olur.
            modelContainer = try ModelContainer(
                for: schema,
                configurations: AppEnvironment.isCloudKitSyncEnabled
                    ? cloudConfiguration
                    : ModelConfiguration(isStoredInMemoryOnly: false, allowsSave: true, cloudKitDatabase: .none)
            )
            startupWarning = nil
        } catch {
            // CloudKit yetkisi/geçici hesabı bozukken uygulamayı doğrudan
            // çökertmek yerine aynı kalıcı mağazayı yerel modda açmayı dene.
            // Bu bir veri sıfırlama değildir; sonraki açılışta CloudKit yeniden denenir.
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        isStoredInMemoryOnly: false,
                        allowsSave: true,
                        cloudKitDatabase: .none
                    )
                )
                startupWarning = "iCloud eşzamanlama başlatılamadı. Veriler bu oturumda yalnızca cihazda kullanılacak."
                _showStartupWarning = State(initialValue: true)
            } catch {
                // Yerel kalıcı mağaza da açılamıyorsa devam etmek veri kaybı
                // izlenimi yaratır; bu kurtarılamaz şema/store hatasıdır.
                fatalError("SwiftData ModelContainer başlatılamadı: \(error.localizedDescription)")
            }
        }
        // Backfill addedToHistoryAt for existing completed reminders
        migrateCompletedReminderHistoryFlags(context: modelContainer.mainContext)
        // Backfill vehicle photo data for CloudKit sync readiness
        backfillVehiclePhotoData(context: modelContainer.mainContext)
    }

    // MARK: - UIKit Appearance Configuration
    /// Tab bar ve segmented control için "Cockpit Black" görünüm.
    /// Turkuaz vurgu, AMOLED siyah zemin, nötr hairline üst çizgi.
    /// NOT: Buradaki UIColor değerleri AppColors token'larıyla eşleşmek zorunda
    /// (accentPrimary #00E5C7, backgroundSecondary #0A0A0A, textSecondary #9A9AA0, border #2A2A2C).
    private static func configureAppearance() {
        // Turkuaz vurgu
        let accentColor = UIColor(red: 0x00/255, green: 0xE5/255, blue: 0xC7/255, alpha: 1.0)
        let hairlineColor = UIColor(red: 0x2A/255, green: 0x2A/255, blue: 0x2C/255, alpha: 1.0)
        let secondaryTextColor = UIColor(red: 0x9A/255, green: 0x9A/255, blue: 0xA0/255, alpha: 1.0)
        let surfaceColor = UIColor(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255, alpha: 0.85)

        // Tab bar — glassmorphism + turkuaz aktif ikon
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = surfaceColor
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabBarAppearance.shadowColor = hairlineColor // Üst kenar nötr hairline

        let tabBarItemAppearance = UITabBarItemAppearance()
        // Selected — turkuaz
        tabBarItemAppearance.selected.iconColor = accentColor
        tabBarItemAppearance.selected.titleTextAttributes = [.foregroundColor: accentColor]
        // Unselected — secondary text
        tabBarItemAppearance.normal.iconColor = secondaryTextColor
        tabBarItemAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryTextColor]

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Segmented control — dark-only
        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: secondaryTextColor],
            for: .normal
        )
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: accentColor],
            for: .selected
        )
    }

    var body: some Scene {
        WindowGroup {
            OnboardingGate {
                BrandIntroView {
                    AppRouter()
                }
                .modelContainer(modelContainer)
                .environmentObject(paywallService)
                .environmentObject(navigationRouter)
                .environment(\.locale, Locale(identifier: "tr_TR"))
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-ArviaSeedDemoData") {
                        DemoDataSeeder.seed(context: modelContainer.mainContext)
                    }
                    #endif
                    navigationRouter.configureNotificationDelegate()
                    NotificationService.shared.clearBadge()
                    await scheduleRetentionNotifications()
                }
                .onChange(of: onboardingCompleted) { _, completed in
                    if completed {
                        // App sil-yeniden yükle senaryosunda CloudKit sync açıkken
                        // SwiftData araç verileri iCloud'tan geri gelir, ama
                        // `onboarding_completed` AppStorage sıfırlanmış olduğu için
                        // onboarding yeniden gösterilir. Onboarding tamamlanınca
                        // wizard'ı koşulsuz açmak kullanıcının zaten sahip olduğu
                        // aracı ikinci kez eklemesine (kopyaya) yol açar.
                        // Bu yüzden: SwiftData'da herhangi bir Vehicle kaydı varsa
                        // (aktif veya arşivli — önemli olan veri tabanında iz olması)
                        // wizard'ı atlıyoruz. Yeni kullanıcıda kayıt sayısı 0 →
                        // wizard normal açılır.
                        do {
                            let existingVehicles = try modelContainer.mainContext.fetchCount(FetchDescriptor<Vehicle>())
                            if existingVehicles == 0 {
                                postOnboardingSheet = .wizard
                            }
                        } catch {
                            // Okuma hatasında 0 varsaymak kopya araç ve limit atlatma riski yaratır.
                            Self.logger.error("Onboarding vehicle count failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
                .sheet(item: $postOnboardingSheet) { _ in
                    VehicleWizardView()
                        .modelContainer(modelContainer)
                        .environmentObject(paywallService)
                }
                .preferredColorScheme(.dark)
                .alert("iCloud Eşzamanlama Kullanılamıyor", isPresented: $showStartupWarning) {
                    Button("Tamam", role: .cancel) {}
                } message: {
                    Text(startupWarning ?? "")
                }
            }
        }
    }

    // MARK: - Retention Notifications
    private func scheduleRetentionNotifications() async {
        // Ana context'te fetch yap
        let context = modelContainer.mainContext
        let vehicles: [Vehicle]
        let reminders: [Reminder]
        do {
            vehicles = try context.fetch(FetchDescriptor<Vehicle>())
            reminders = try context.fetch(FetchDescriptor<Reminder>())
        } catch {
            Self.logger.error("Startup notification fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Dosya tamlık skoru hesapla
        var fileScores: [UUID: Int] = [:]
        for vehicle in vehicles {
            var score = 0
            if !vehicle.brand.isEmpty { score += 10 }
            if !vehicle.model.isEmpty { score += 10 }
            if vehicle.year != nil { score += 10 }
            if vehicle.currentOdometer > 0 { score += 10 }
            if vehicle.transmissionType != nil { score += 10 }
            if vehicle.purchaseDate != nil { score += 10 }
            if vehicle.purchasePrice != nil { score += 10 }
            if vehicle.vehicleType == .motorcycle, vehicle.engineCC != nil { score += 10 }
            let vehicleReminders = reminders.filter { $0.vehicleId == vehicle.id }
            if !vehicleReminders.isEmpty { score += 15 }
            if !vehicleReminders.contains(where: { $0.isOverdue }) { score += 15 }
            fileScores[vehicle.id] = min(score, 100)
        }

        await RetentionNotificationService.shared.rescheduleAll(
            vehicles: vehicles,
            fileScores: fileScores
        )
    }

    // MARK: - Migrate
    /// Backfill addedToHistoryAt for pre-existing completed reminders.
    /// Yeni addedToHistoryAt alanı SwiftData'da optional → nil default.
    /// Eskiden completedAt set olanlar otomatik olarak Geçmiş'te görünsün.
    private func migrateCompletedReminderHistoryFlags(context: ModelContext) {
        let predicate = #Predicate<Reminder> { $0.completedAt != nil && $0.addedToHistoryAt == nil }
        let descriptor = FetchDescriptor<Reminder>(predicate: predicate)
        let pending: [Reminder]
        do {
            pending = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Completed reminder migration fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard !pending.isEmpty else { return }
        for reminder in pending {
            reminder.addedToHistoryAt = reminder.completedAt
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Completed reminder migration save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Mevcut araçların disk fotoğrafını photoData'ya taşır (CloudKit senkron hazırlığı).
    private func backfillVehiclePhotoData(context: ModelContext) {
        let vehicles: [Vehicle]
        do {
            vehicles = try context.fetch(FetchDescriptor<Vehicle>())
        } catch {
            Self.logger.error("Vehicle photo backfill fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        var changed = false
        for vehicle in vehicles where vehicle.photoData == nil {
            guard let fileName = vehicle.photoFileName,
                  let data = VehiclePhotoStorageService.shared.readPhotoData(fileName: fileName) else { continue }
            vehicle.photoData = data
            changed = true
        }
        guard changed else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Vehicle photo backfill save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
