import SwiftUI
import SwiftData

// MARK: - Belgeler (Documents) Tab
// Belge kasası: türe göre gruplandırılmış liste, ekleme, önizleme.

struct DocumentsView: View {
    @State private var showAddDocument = false

    var body: some View {
        NavigationStack {
            DocumentListView()
                .navigationTitle("Belgeler")
                .background(Color.appBackground)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddDocument = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(AppColors.accentPrimary)
                        }
                        .accessibilityLabel("Belge Ekle")
                    }
                }
                .sheet(isPresented: $showAddDocument) {
                    DocumentFormView()
                }
        }
    }
}

#Preview("Belgeler — Boş") {
    DocumentsView()
}

#Preview("Belgeler — Dolu") {
    DocumentsView()
        .modelContainer(MockDataProvider.previewContainer)
}
