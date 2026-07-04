import SwiftUI
import SwiftData

// MARK: - App Entry Point
// @main uygulama girişi.
// SwiftData container yapılandırması ve root view.

@main
struct VehicleDossierApp: App {
    let modelContainer: ModelContainer
    @StateObject private var paywallService = PaywallService.shared
    @StateObject private var communityAuthService = CommunityAuthService.shared
    @StateObject private var navigationRouter = AppNavigationRouter.shared
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    /// Onboarding sonrası açılacak sheet tipi — her durumda tek tip wizard kullanılır.
    @State private var postOnboardingSheet: PostOnboardingSheet?
    private enum PostOnboardingSheet: Identifiable {
        case wizard
        var id: String { "wizard" }
    }

    init() {
        Self.configureAppearance()
        do {
            let schema = Schema([
                Vehicle.self,
                Reminder.self,
                Expense.self,
                ServiceRecord.self,
                PartChange.self,
                VehicleDocument.self,
                InspectionReport.self,
                SaleFile.self,
            ])
            // CloudKit private database sync — yalnızca feature flag açıkken devreye girer.
            // Flag kapalıyken `.none` ile bugünkü davranış birebir korunur (sadece yerel).
            // Flag'i açmadan ÖNCE Xcode'da iCloud/CloudKit capability'si ve aşağıdaki
            // container kimliği eklenmelidir; aksi halde container init eder ve fatalError olur.
            let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = AppEnvironment.isCloudKitSyncEnabled
                ? .private("iCloud.com.ruhsatim.app")
                : .none
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: cloudKitDatabase
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: modelConfiguration
            )
            // Backfill addedToHistoryAt for existing completed reminders
            migrateCompletedReminderHistoryFlags(context: modelContainer.mainContext)
        } catch {
            fatalError("SwiftData ModelContainer başlatılamadı: \(error.localizedDescription)")
        }
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
                .environmentObject(communityAuthService)
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
                    await communityAuthService.restoreSession()
                    await scheduleRetentionNotifications()
                }
                .onChange(of: onboardingCompleted) { _, completed in
                    if completed {
                        // Onboarding sonrası her zaman tek tip wizard açılır.
                        postOnboardingSheet = .wizard
                    }
                }
                .sheet(item: $postOnboardingSheet) { _ in
                    VehicleWizardView()
                        .modelContainer(modelContainer)
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Retention Notifications
    private func scheduleRetentionNotifications() async {
        // Ana context'te fetch yap
        let context = modelContainer.mainContext
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []

        // Dosya tamlık skoru hesapla
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
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
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }
        for reminder in pending {
            reminder.addedToHistoryAt = reminder.completedAt
        }
        try? context.save()
    }
}
