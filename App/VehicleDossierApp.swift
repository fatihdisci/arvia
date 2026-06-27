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
        } catch {
            fatalError("SwiftData ModelContainer başlatılamadı: \(error.localizedDescription)")
        }
    }

    // MARK: - UIKit Appearance Configuration
    /// Tab bar ve segmented control için light/dark mode adaptive
    /// UIKit appearance proxy ayarları.
    private static func configureAppearance() {
        // Tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1.0)  // #111827
                : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)         // #FFFFFF
        }

        let tabBarItemAppearance = UITabBarItemAppearance()
        // Selected
        tabBarItemAppearance.selected.iconColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1.0)   // #2DD4BF
                : UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1.0)   // #0F766E
        }
        tabBarItemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1.0)
                    : UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1.0)
            }
        ]
        // Unselected
        tabBarItemAppearance.normal.iconColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.580, green: 0.639, blue: 0.722, alpha: 1.0)   // #94A3B8
                : UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1.0)   // #64748B
        }
        tabBarItemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.580, green: 0.639, blue: 0.722, alpha: 1.0)
                    : UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1.0)
            }
        ]

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Segmented control
        let segmentedAppearance = UISegmentedControl.appearance()
        // Normal state: light mode slate, dark mode light-slate
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.580, green: 0.639, blue: 0.722, alpha: 1.0)   // #94A3B8
                    : UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1.0)   // #64748B
            }],
            for: .normal
        )
        // Selected state: light mode dark-accent (visible on white capsule), dark mode white
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor.white
                    : UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1.0)   // #0F766E
            }],
            for: .selected
        )
    }

    var body: some Scene {
        WindowGroup {
            BrandIntroView {
                AppRouter()
                    .modelContainer(modelContainer)
                    .environmentObject(paywallService)
                    .environmentObject(communityAuthService)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                    .task {
                        await communityAuthService.restoreSession()
                        await scheduleRetentionNotifications()
                    }
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
}
