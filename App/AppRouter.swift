import SwiftUI

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

struct AppRouter: View {
    @State private var selectedTab: AppTab = .garage

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(AppColors.accentPrimary)
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
}
