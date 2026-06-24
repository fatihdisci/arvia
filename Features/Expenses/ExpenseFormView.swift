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

    init(existingExpense: Expense? = nil) {
        self.existingExpense = existingExpense
        if let e = existingExpense {
            _selectedCategory = State(initialValue: e.category)
            _amountText = State(initialValue: e.amount > 0 ? String(format: "%.2f", e.amount) : "")
            _date = State(initialValue: e.date)
            _odometerText = State(initialValue: e.odometer.map { String($0) } ?? "")
            _vendorName = State(initialValue: e.vendorName ?? "")
            _note = State(initialValue: e.note)
            _selectedVehicleId = State(initialValue: e.vehicleId)
        }
    }

    private var isEditing: Bool { existingExpense != nil }
    private var amount: Double? { Double(amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
    private var odometer: Int? { Int(odometerText.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle(isEditing ? "Masraf Düzenle" : "Masraf Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Kaydet" : "Ekle", action: saveExpense)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .onAppear {
                if !isEditing, vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
            }
        }
    }

    // MARK: - Category Section
    private var categorySection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: AppSpacing.xs) {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
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
        Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 3) {
                Image(systemName: category.defaultIcon)
                    .font(.body)
                    .foregroundColor(selectedCategory == category ? .white : AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(selectedCategory == category ? AppColors.accentPrimary : AppColors.backgroundSecondary)
                    )
                Text(category.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(selectedCategory == category ? AppColors.accentPrimary : AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
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
                    .keyboardType(.numberPad)
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

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview
#Preview("Masraf Ekleme") {
    ExpenseFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
