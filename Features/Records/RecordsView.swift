import SwiftUI

// MARK: - Kayıtlar (Records) Tab
// Bakım, masraf, belge ve ekspertiz geçmişi (arşiv). "Raporlar" 1.1.0'da
// ayrı bir sekmeye taşındı (bkz. Features/Reports/ReportsView.swift).

struct RecordsView: View {
    var body: some View {
        NavigationStack {
            HistoryView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.appBackground.ignoresSafeArea())
                .navigationTitle("Kayıtlar")
                .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}

#Preview("Kayıtlar") {
    RecordsView()
        .modelContainer(MockDataProvider.previewContainer)
}
