import SwiftUI

// MARK: - Kayıtlar (Records) Tab
// "Geçmiş" (arşiv) ve "Raporlar" (maliyet özeti) tek sekmede birleşir.
// Üstte segmented control ile iki görünüm arasında geçilir; her ikisi de
// kendi NavigationStack'i olmadan bu konteynerin nav bar'ını kullanır.

struct RecordsView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case archive = "Geçmiş"
        case reports = "Raporlar"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .archive

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .archive:
                    HistoryView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                case .reports:
                    ReportsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Görünüm", selection: $segment) {
                    ForEach(Segment.allCases) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)
                .background(Color.appBackground)
            }
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
