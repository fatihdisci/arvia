import SwiftUI

// MARK: - Kayıtlar (Records) Tab
// "Geçmiş" (arşiv) ve "Raporlar" (maliyet özeti) tek sekmede birleşir.
// Segmented control doğrudan navigation bar'ın PRINCIPAL alanında durur.
//
// Neden principal (nav bar içi)?  Önceki denemelerde segment barı, List'in
// (HistoryView) üstünde ya plain sibling ya da safeAreaInset olarak konumlandı.
// Her iki halde de "Geçmiş" seçiliyken bar üst bara gömülüyordu: List, büyük
// başlık (.inlineLarge) collapse davranışıyla birlikte kendi üst güvenli alanını
// yeniden hesapladığı için bar'ı yiyordu. Segment control'ü nav bar'ın kendi
// içine (principal) koymak bu sınıf sorunu tamamen ortadan kaldırır — bar artık
// scroll'dan bağımsız, sabit nav bar yüksekliğinin bir parçası.
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
                case .reports:
                    ReportsView()
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Görünüm", selection: $segment) {
                        ForEach(Segment.allCases) { seg in
                            Text(seg.rawValue).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
        }
    }
}

#Preview("Kayıtlar") {
    RecordsView()
        .modelContainer(MockDataProvider.previewContainer)
}
