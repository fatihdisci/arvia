import SwiftUI
import UserNotifications

// MARK: - App Router
// Ana tab navigation yapısı.
// 5 sekme: Garaj, Yapılacaklar, Geçmiş, Raporlar, Topluluk
// Not: Belgeler sekmesi kaldırıldı — belge erişimi Araç Detay'da.

enum AppTab: String, CaseIterable {
    case garage
    case todos
    case history
    case reports
    case community

    var title: LocalizedStringKey {
        switch self {
        case .garage: return "Garaj"
        case .todos: return "Yapılacaklar"
        case .history: return "Geçmiş"
        case .reports: return "Raporlar"
        case .community: return "Topluluk"
        }
    }

    var icon: String {
        switch self {
        case .garage: return "car"
        case .todos: return "checklist"
        case .history: return "clock.arrow.circlepath"
        case .reports: return "chart.bar"
        case .community: return "person.3"
        }
    }
}

enum VehicleNotificationFocus: String, Equatable {
    case kmUpdate
    case fileCompleteness
    case saleFile
}

enum TodoNotificationFocus: String, Equatable {
    case reminder
    case seasonalMaintenance
}

enum AppNotificationRoute: Equatable {
    case reminder(vehicleId: UUID, reminderId: UUID)
    case vehicle(vehicleId: UUID, focus: VehicleNotificationFocus)
    case reports
    case todos(focus: TodoNotificationFocus)

    init?(userInfo: [AnyHashable: Any]) {
        guard let deepLink = userInfo["deepLink"] as? String else { return nil }
        switch deepLink {
        case "reminder":
            guard let vehicleString = userInfo["vehicleId"] as? String,
                  let reminderString = userInfo["reminderId"] as? String,
                  let vehicleId = UUID(uuidString: vehicleString),
                  let reminderId = UUID(uuidString: reminderString) else { return nil }
            self = .reminder(vehicleId: vehicleId, reminderId: reminderId)
        case "kmUpdate":
            guard let vehicleId = Self.vehicleId(from: userInfo) else { return nil }
            self = .vehicle(vehicleId: vehicleId, focus: .kmUpdate)
        case "fileCompleteness":
            guard let vehicleId = Self.vehicleId(from: userInfo) else { return nil }
            self = .vehicle(vehicleId: vehicleId, focus: .fileCompleteness)
        case "saleFile":
            guard let vehicleId = Self.vehicleId(from: userInfo) else { return nil }
            self = .vehicle(vehicleId: vehicleId, focus: .saleFile)
        case "monthlySummary":
            self = .reports
        case "seasonalMaintenance":
            self = .todos(focus: .seasonalMaintenance)
        default:
            return nil
        }
    }

    var targetTab: AppTab {
        switch self {
        case .reminder, .todos:
            return .todos
        case .vehicle:
            return .garage
        case .reports:
            return .reports
        }
    }

    var vehicleId: UUID? {
        switch self {
        case .reminder(let vehicleId, _): return vehicleId
        case .vehicle(let vehicleId, _): return vehicleId
        case .reports, .todos: return nil
        }
    }

    private static func vehicleId(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let vehicleString = userInfo["vehicleId"] as? String else { return nil }
        return UUID(uuidString: vehicleString)
    }
}

@MainActor
final class AppNavigationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = AppNavigationRouter()

    @Published var selectedTab: AppTab = .garage
    @Published var pendingNotificationRoute: AppNotificationRoute?

    private override init() {
        super.init()
    }

    func configureNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func route(_ route: AppNotificationRoute) {
        pendingNotificationRoute = route
        selectedTab = route.targetTab
        NotificationService.shared.clearBadge()
    }

    func clearRouteIfHandled(_ route: AppNotificationRoute) {
        if pendingNotificationRoute == route {
            pendingNotificationRoute = nil
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let route = AppNotificationRoute(userInfo: response.notification.request.content.userInfo) else { return }
        await MainActor.run { self.route(route) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

struct AppRouter: View {
    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    @EnvironmentObject private var paywallService: PaywallService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var showAssistantProfile = false
    // Post-purchase asistan profili akışı yalnızca bir kez otomatik sunulur.
    @AppStorage("assistant_profile_prompted") private var assistantProfilePrompted = false

    var body: some View {
        TabView(selection: $navigationRouter.selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(AppColors.accentPrimary)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationService.shared.clearBadge()
            }
        }
        // Trigger (a): Pro satın alma / geri yükleme sonrası isPro true'ya döndüğünde
        // Kullanım Profili akışını sun (profil henüz yoksa).
        .onChange(of: paywallService.isPro) { wasPro, isPro in
            guard isPro, !wasPro, paywallService.canUseAssistant else { return }
            let hasProfile = UsageProfileService.shared.globalProfile(context: modelContext) != nil
            assistantProfilePrompted = true
            if !hasProfile { showAssistantProfile = true }
        }
        .sheet(isPresented: $showAssistantProfile) {
            UsageProfileFlowView()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .garage:
            GarageView()
        case .todos:
            TodosView()
        case .history:
            HistoryView()
        case .reports:
            ReportsView()
        case .community:
            CommunityFeedView()
        }
    }
}

#Preview("AppRouter") {
    AppRouter()
        .environmentObject(AppNavigationRouter.shared)
        .environmentObject(PaywallService.shared)
        .modelContainer(MockDataProvider.previewContainer)
}
