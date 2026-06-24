import SwiftUI
import SwiftData

// MARK: - App Entry Point
// @main uygulama girişi.
// SwiftData container yapılandırması ve root view.

@main
struct VehicleDossierApp: App {
    let modelContainer: ModelContainer
    @StateObject private var paywallService = PaywallService.shared

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
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: modelConfiguration
            )
        } catch {
            fatalError("SwiftData ModelContainer başlatılamadı: \(error.localizedDescription)")
        }
    }

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

        // Navigation bar
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Segmented control
        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1.0)],  // #64748B
            for: .normal
        )
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .modelContainer(modelContainer)
                .environmentObject(paywallService)
                .environment(\.locale, Locale(identifier: "tr_TR"))
        }
    }
}
