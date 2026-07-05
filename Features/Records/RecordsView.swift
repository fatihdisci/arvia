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
            VStack(spacing: 0) {
                Picker("Görünüm", selection: $segment) {
                    ForEach(Segment.allCases) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)

                Group {
                    switch segment {
                    case .archive:
                        HistoryView()
                    case .reports:
                        ReportsView()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
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
