import SwiftUI

// MARK: - Quick Odometer Update Sheet
struct QuickOdometerUpdateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    @State private var odometerText: String
    @State private var errorMessage: String?
    @State private var showLowerConfirmation = false
    @State private var pendingLowerValue: Int?
    @FocusState private var isInputFocused: Bool
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _odometerText = State(initialValue: vehicle.currentOdometer > 0 ? String(vehicle.currentOdometer) : "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Mevcut km").foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(vehicle.odometerDisplay).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary)
                    }
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "gauge.with.needle").foregroundColor(AppColors.textTertiary)
                        TextField("Yeni km", text: $odometerText).keyboardType(.decimalPad).focused($isInputFocused)
                    }
                } footer: {
                    Text("Güncel kilometre, bakım ve masraf takibini daha doğru hale getirir.")
                        .font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                }
                .listRowBackground(Color.appSurface)
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.secondary).foregroundColor(AppColors.critical)
                    }
                    .listRowBackground(AppColors.criticalBackground)
                }
            }
            .scrollContentBackground(.hidden).background(Color.appBackground)
            .navigationTitle("Kilometreyi Güncelle").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.foregroundColor(AppColors.textSecondary) }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet", action: validateAndSave).font(AppTypography.bodyMedium).foregroundColor(AppColors.accentPrimary) }
            }
            .onAppear { isInputFocused = true }
            .confirmationDialog("Daha düşük km kaydedilsin mi?", isPresented: $showLowerConfirmation) {
                Button("Daha düşük km ile kaydet") { if let pendingLowerValue { save(pendingLowerValue) } }
                Button("İptal", role: .cancel) {}
            } message: { Text("Yeni km mevcut km'den düşük. Bunu yalnızca önceki kaydı düzeltmek istiyorsan onayla.") }
        }
    }
    private func validateAndSave() {
        errorMessage = nil
        let result = VehicleInsightService.shared.validateOdometerInput(odometerText, currentOdometer: vehicle.currentOdometer, allowLowerValue: false)
        switch result {
        case .valid: if let v = VehicleInsightService.shared.parsedOdometer(odometerText) { save(v) }
        case .empty: errorMessage = "Yeni kilometre değerini girmelisin."
        case .invalid: errorMessage = "Geçerli bir kilometre değeri girmelisin."
        case .negative: errorMessage = "Km sıfırdan küçük olamaz."
        case .lowerNeedsConfirmation: pendingLowerValue = VehicleInsightService.shared.parsedOdometer(odometerText); showLowerConfirmation = true
        }
    }
    private func save(_ value: Int) {
        Task {
            do {
                try await VehicleContextRefreshService.updateCurrentOdometer(vehicle: vehicle, newOdometer: value, context: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch { errorMessage = "Kaydedilemedi: \(error.localizedDescription)" }
        }
    }
}
