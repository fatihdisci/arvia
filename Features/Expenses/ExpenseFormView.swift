import SwiftUI
import SwiftData

// MARK: - Expense Form View
// Masraf ekleme ve düzenleme sheet'i.
// 17 kategori, tutar (TRY), tarih, km, firma, not.

struct ExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    // Edit mode
    let existingExpense: Expense?

    // Form fields
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var amountText = ""
    @State private var date = Date()
    @State private var odometerText = ""
    @State private var vendorName = ""
    @State private var note = ""
    @State private var selectedVehicleId: UUID?

    @State private var validationErrors: [String] = []
    @State private var showReceiptScan = false
    @State private var showReceiptPaywall = false

    init(existingExpense: Expense? = nil, preselectedVehicleId: UUID? = nil, preselectedCategory: ExpenseCategory? = nil) {
        self.existingExpense = existingExpense
        if let e = existingExpense {
            _selectedCategory = State(initialValue: e.category)
            _amountText = State(initialValue: e.amount > 0 ? String(format: "%.2f", e.amount) : "")
            _date = State(initialValue: e.date)
            _odometerText = State(initialValue: e.odometer.map { String($0) } ?? "")
            _vendorName = State(initialValue: e.vendorName ?? "")
            _note = State(initialValue: e.note)
            _selectedVehicleId = State(initialValue: e.vehicleId)
        } else if let vid = preselectedVehicleId {
            _selectedVehicleId = State(initialValue: vid)
            if let preselectedCategory {
                _selectedCategory = State(initialValue: preselectedCategory)
            }
        } else if let preselectedCategory {
            _selectedCategory = State(initialValue: preselectedCategory)
        }
    }

    private var isEditing: Bool { existingExpense != nil }
    private var amount: Double? { Double(amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
    private var odometer: Int? { Int(odometerText.sanitizedIntInput()) }

    /// Kaydet butonunun etkin olması için gereken minimum (kesin zorunlu) alanlar.
    /// Format/aralık doğrulamaları kaydetme anındaki hata mesajlarında ele alınır;
    /// burada yalnızca "boş zorunlu alan" durumunda buton kapatılır (fazla kapatma yok).
    private var canSave: Bool {
        (amount ?? 0) > 0 && selectedVehicleId != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    scanSection
                }
                categorySection
                amountSection
                detailSection
                vehicleSection

                if !validationErrors.isEmpty {
                    errorSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(preselectedVehicleId: selectedVehicleId)
            }
            .sheet(isPresented: $showReceiptPaywall) {
                PaywallView(feature: .receiptScan)
                    .environmentObject(PaywallService.shared)
            }
            .onChange(of: selectedVehicleId) { _, _ in
                // Araç değişince geçersiz kategoriyi safe default'a döndür
                if !availableCategories.contains(selectedCategory) {
                    selectedCategory = .other
                }
            }
            .navigationTitle(isEditing ? "Masraf Düzenle" : "Masraf Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // .borderless: sistemin confirmationAction'a verdiği dolgulu
                    // görünümü kaldırır — anayasa: filled primary yasak.
                    Button(isEditing ? "Kaydet" : "Ekle", action: saveExpense)
                        .buttonStyle(.borderless)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(canSave ? AppColors.accentPrimary : AppColors.textTertiary)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if !isEditing, vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
            }
        }
    }

    // MARK: - Scan Section
    /// Fiş/fatura tarama girişi. Non-Pro kullanıcı paywall görür (mevcut gate deseni).
    private var scanSection: some View {
        Section {
            Button {
                if PaywallService.shared.canUseReceiptScan {
                    showReceiptScan = true
                } else {
                    showReceiptPaywall = true
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.viewfinder")
                        .foregroundColor(AppColors.accentPrimary)
                    Text("Fiş/Fatura Tara")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                    Spacer()
                    if !PaywallService.shared.canUseReceiptScan {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fiş veya fatura tara")
        } footer: {
            Text("Fişi tarat, tutar ve tarih otomatik dolsun.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Category Section
    /// Seçili aracın vehicleType'ına göre filtrelenmiş kategoriler.
    private var availableCategories: [ExpenseCategory] {
        guard let vid = selectedVehicleId, let vehicle = vehicles.first(where: { $0.id == vid }) else {
            return ExpenseCategory.categories(for: nil) + [.other]
        }
        return ExpenseCategory.categories(for: vehicle.vehicleType) + [.other]
    }

    private var categorySection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: AppSpacing.xs) {
                ForEach(availableCategories, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
        } header: {
            Text("Kategori")
        }
        .listRowBackground(Color.appSurface)
    }

    private func categoryButton(_ category: ExpenseCategory) -> some View {
        let isSelected = selectedCategory == category
        // Seçim = outline + muted dolgu + tik (anayasa: filled seçim yerine bordered).
        return Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? "checkmark" : category.defaultIcon)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.accentPrimary : AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(isSelected ? AppColors.accentMuted : AppColors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .stroke(isSelected ? AppColors.accentPrimary : Color.clear, lineWidth: 1.2)
                    )
                Text(category.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.accentPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Amount Section
    private var amountSection: some View {
        Section {
            HStack(spacing: AppSpacing.xs) {
                Text("₺")
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textTertiary)
                TextField("0,00", text: $amountText)
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Tutar")
        } footer: {
            Text("Tüm masraflar Türk Lirası (₺) üzerinden kaydedilir.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Detail Section
    private var detailSection: some View {
        Section {
            DatePicker(selection: $date, displayedComponents: .date) {
                Label("Tarih", systemImage: "calendar")
                    .font(AppTypography.body)
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "gauge.with.needle")
                    .foregroundColor(AppColors.textTertiary)
                TextField("Km (isteğe bağlı)", text: $odometerText)
                    .keyboardType(.decimalPad)
                    .font(AppTypography.body)
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.2")
                    .foregroundColor(AppColors.textTertiary)
                TextField("Firma / Usta (isteğe bağlı)", text: $vendorName)
                    .font(AppTypography.body)
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "pencil.line")
                    .foregroundColor(AppColors.textTertiary)
                TextField("Not (isteğe bağlı)", text: $note)
                    .font(AppTypography.body)
            }
        } header: {
            Text("Detaylar")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Vehicle Section
    private var vehicleSection: some View {
        Section {
            if vehicles.isEmpty {
                Label("Önce bir araç eklemelisin.", systemImage: "exclamationmark.triangle")
                    .foregroundColor(AppColors.warning)
            } else {
                Picker(selection: $selectedVehicleId) {
                    Text("Seç").tag(nil as UUID?)
                    ForEach(vehicles) { vehicle in
                        Text(vehicle.plate.isEmpty ? vehicle.fullName : "\(vehicle.plate) — \(vehicle.fullName)")
                            .tag(vehicle.id as UUID?)
                    }
                } label: {
                    Label("Araç", systemImage: "car")
                        .font(AppTypography.body)
                }
            }
        } header: {
            Text("Araç")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Error Section
    private var errorSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { error in
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.critical)
            }
        } header: {
            Text("Eksik Bilgiler")
                .foregroundColor(AppColors.critical)
        }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - Save
    private func saveExpense() {
        var errors: [String] = []

        if amount == nil || !(amount! > 0) {
            errors.append("Geçerli bir tutar girmelisin.")
        }

        guard let vehicleId = selectedVehicleId else {
            errors.append("Bir araç seçmelisin.")
            validationErrors = errors
            return
        }

        if !errors.isEmpty {
            validationErrors = errors
            return
        }

        if let existing = existingExpense {
            // Güncelle
            existing.categoryRaw = selectedCategory.rawValue
            existing.amount = amount ?? 0
            existing.date = date
            existing.odometer = odometer
            existing.vendorName = vendorName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : vendorName.trimmingCharacters(in: .whitespaces)
            existing.note = note.trimmingCharacters(in: .whitespaces)
        } else {
            // Yeni kayıt
            let expense = Expense(
                vehicleId: vehicleId,
                category: selectedCategory,
                amount: amount ?? 0,
                date: date,
                odometer: odometer,
                vendorName: vendorName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : vendorName.trimmingCharacters(in: .whitespaces),
                note: note.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(expense)
        }

        do {
            try modelContext.save()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            Task { await VehicleContextRefreshService.refreshAfterVehicleContextChange(context: modelContext) }
            dismiss()
        } catch {
            modelContext.rollback()
            validationErrors = ["Kaydedilemedi: \(error.localizedDescription)"]
        }
    }
}

// MARK: - Preview
#Preview("Masraf Ekleme") {
    ExpenseFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
