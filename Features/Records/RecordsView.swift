import SwiftUI

// MARK: - Kayıtlar (Records) Tab
// "Geçmiş" (arşiv) ve "Raporlar" (maliyet özeti) tek sekmede birleşir.
// Segment control artık burada değil — HistoryView/ReportsView'a binding olarak
// geçiliyor, ikisi de kendi üst safeAreaInset'ine (doğrudan List/ScrollView'u
// saran) gömüyor. Neden: bu control'ü List'ten bir seviye uzakta tutmak (bu
// dosyanın kendi safeAreaInset'i, önceki sürüm), Geçmiş seçiliyken List'in üst
// güvenli alanı nav bar'a göre yeniden hesaplanırken control'ü üst bara
// "yutuyordu". Nav bar principal'a taşımak da denendi ama "Kayıtlar" büyük
// başlığını kaybettirdiği için revert edildi — bkz. git log (3dc9c14 / f58705a).
// O yüzden: navigationTitle/toolbarTitleDisplayMode'a burada dokunma.

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
                    HistoryView(segment: $segment)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                case .reports:
                    ReportsView(segment: $segment)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Kayıtlar")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}

// MARK: - Shared segment picker
// HistoryView ve ReportsView tarafından doğrudan kullanılıyor, ikisi de bunu
// kendi List/ScrollView'ünü SARAN tek safeAreaInset'in içine koyuyor. Bunu
// tekrar RecordsView'ın kendi Group'una taşıma — yukarıdaki yorum ve
// HistoryView.swift'teki ilgili yorum bunun neden işe yaramadığını açıklıyor.
struct RecordsSegmentPicker: View {
    @Binding var segment: RecordsView.Segment

    var body: some View {
        Picker("Görünüm", selection: $segment) {
            ForEach(RecordsView.Segment.allCases) { seg in
                Text(seg.rawValue).tag(seg)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.sm)
    }
}

#Preview("Kayıtlar") {
    RecordsView()
        .modelContainer(MockDataProvider.previewContainer)
}
