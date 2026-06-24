import SwiftUI

// MARK: - Kayıtlar (Records) Tab
// Masraf ve bakım kayıtlarını tek sekmede gösterir.
// Segmented control ile Masraflar / Bakımlar arasında geçiş.

struct RecordsView: View {
    @State private var selectedTab: RecordTab = .expenses
    @State private var showAddExpense = false
    @State private var showAddService = false

    enum RecordTab: String, CaseIterable {
        case expenses = "Masraflar"
        case services = "Bakımlar"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(RecordTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppColors.accentPrimary)
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.vertical, AppSpacing.xs)

                // İçerik
                switch selectedTab {
                case .expenses:
                    ExpenseListView()
                case .services:
                    ServiceRecordListView()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Kayıtlar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        switch selectedTab {
                        case .expenses: showAddExpense = true
                        case .services: showAddService = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) { ExpenseFormView() }
            .sheet(isPresented: $showAddService) { ServiceRecordFormView() }
        }
    }
}

#Preview("Kayıtlar") {
    RecordsView()
        .modelContainer(MockDataProvider.previewContainer)
}
