import SwiftUI
import SwiftData

// MARK: - Reminder Form View
// Hatırlatıcı ekleme/düzenleme sheet'i. Şablon seçimi, tarih/km, tekrar, öncelik, araç bağlantısı.

struct ReminderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    let existingReminder: Reminder?
    private var isEditing: Bool { existingReminder != nil }

    // Şablon
    @State private var selectedTemplate: ReminderType = .custom
    @State private var customTitle = ""

    // Tarih / Km
    @State private var dueDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var hasDueDate = true
    @State private var dueOdometerText = ""
    @State private var hasDueOdometer = false

    // Tekrar
    @State private var repeatRule: ReminderRepeatRule = .none

    // Öncelik
    @State private var priority: ReminderPriority = .warning

    // Araç
    @State private var selectedVehicleId: UUID?

    // Not
    @State private var notes = ""

    @State private var validationErrors: [String] = []

    init(
        existingReminder: Reminder? = nil,
        preselectedVehicleId: UUID? = nil,
        preselectedTemplate: ReminderType? = nil,
        prefilledTitle: String? = nil,
        prefilledDueOdometer: Int? = nil,
        prefilledDueInMonths: Int? = nil
    ) {
        self.existingReminder = existingReminder
        if let r = existingReminder {
            _selectedTemplate = State(initialValue: r.type)
            _customTitle = State(initialValue: r.type == .custom ? r.title : "")
            _dueDate = State(initialValue: r.dueDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
            _hasDueDate = State(initialValue: r.dueDate != nil)
            _dueOdometerText = State(initialValue: r.dueOdometer.map { String($0) } ?? "")
            _hasDueOdometer = State(initialValue: r.dueOdometer != nil)
            _repeatRule = State(initialValue: ReminderRepeatRule(rawValue: r.repeatRuleRaw ?? "none") ?? .none)
            _priority = State(initialValue: r.priority)
            _selectedVehicleId = State(initialValue: r.vehicleId)
            _notes = State(initialValue: r.notes)
        } else {
            if let vid = preselectedVehicleId {
                _selectedVehicleId = State(initialValue: vid)
            }
            if let preselectedTemplate {
                _selectedTemplate = State(initialValue: preselectedTemplate)
            }
            // AI/plan önerisinden önden doldurma (additive).
            if let prefilledTitle, !prefilledTitle.isEmpty {
                _selectedTemplate = State(initialValue: .custom)
                _customTitle = State(initialValue: prefilledTitle)
            }
            if let prefilledDueOdometer {
                _hasDueOdometer = State(initialValue: true)
                _dueOdometerText = State(initialValue: String(prefilledDueOdometer))
            }
            if let prefilledDueInMonths {
                _hasDueDate = State(initialValue: true)
                _dueDate = State(initialValue: Calendar.current.date(byAdding: .month, value: prefilledDueInMonths, to: Date()) ?? Date())
            }
        }
    }

    /// Seçili araca göre filtrelenmiş şablon listesi.
    private var availableTemplates: [ReminderType] {
        guard let vid = selectedVehicleId, let vehicle = vehicles.first(where: { $0.id == vid }) else {
            return ReminderType.templates(for: nil)
        }
        return ReminderType.templates(for: vehicle.vehicleType)
    }

    // ReminderRepeatRule enum'u shared olarak ReminderRepeatEngine.swift içinde tanımlı.
    // .custom opsiyonu UI'da gizlenir (henüz desteklenmiyor).

    private var displayTitle: String {
        if selectedTemplate == .custom {
            return customTitle.isEmpty ? "Yeni Hatırlatıcı" : customTitle
        }
        return selectedTemplate.displayName
    }

    /// Kaydet için kesin zorunlu alanlar: araç seçimi ve (özel şablonda) ad.
    private var canSave: Bool {
        guard selectedVehicleId != nil else { return false }
        if selectedTemplate == .custom {
            return !customTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                templateSection
                detailSection
                vehicleSection
                prioritySection

                if !validationErrors.isEmpty {
                    errorSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Hatırlatıcı Düzenle" : "Hatırlatıcı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Kaydet" : "Ekle", action: saveReminder)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(canSave ? AppColors.accentPrimary : AppColors.textTertiary)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
            }
        }
    }

    // MARK: - Template Section
    private var templateSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: AppSpacing.xs) {
                ForEach(availableTemplates + [ReminderType.custom], id: \.self) { type in
                    templateButton(type)
                }
            }
            .padding(.vertical, AppSpacing.xxs)

            if selectedTemplate == .custom {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "pencil")
                        .foregroundColor(AppColors.textTertiary)
                    TextField("Hatırlatıcı adı", text: $customTitle)
                        .font(AppTypography.body)
                }
            }
        } header: {
            Text("Şablon Seç")
        }
        .listRowBackground(Color.appSurface)
    }

    private func templateButton(_ type: ReminderType) -> some View {
        Button {
            selectedTemplate = type
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.defaultIcon)
                    .font(.title3)
                    .foregroundColor(selectedTemplate == type ? .white : AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(selectedTemplate == type ? AppColors.accentPrimary : AppColors.backgroundSecondary)
                    )

                Text(type.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(selectedTemplate == type ? AppColors.accentPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Section
    private var detailSection: some View {
        Section {
            Toggle(isOn: $hasDueDate) {
                Label("Tarih", systemImage: "calendar")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)

            if hasDueDate {
                DatePicker("Tarih", selection: $dueDate, displayedComponents: .date)
                    .font(AppTypography.body)
            }

            Toggle(isOn: $hasDueOdometer) {
                Label("Km sınırı", systemImage: "gauge.with.needle")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)

            if hasDueOdometer {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "gauge.with.needle")
                        .foregroundColor(AppColors.textTertiary)
                    TextField("Hedef km", text: $dueOdometerText)
                        .keyboardType(.decimalPad)
                        .font(AppTypography.body)
                }
            }

            Picker(selection: $repeatRule) {
                ForEach(ReminderRepeatRule.allCases.filter { $0 != .custom }, id: \.self) { rule in
                    Text(rule.displayName).tag(rule)
                }
            } label: {
                Label("Tekrar", systemImage: "repeat")
                    .font(AppTypography.body)
            }
        } header: {
            Text("Zamanlama")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Vehicle Section
    private var vehicleSection: some View {
        Section {
            if vehicles.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(AppColors.warning)
                    Text("Önce bir araç eklemelisin.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                }
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
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        } header: {
            Text("Araç")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Priority Section
    private var prioritySection: some View {
        Section {
            Picker(selection: $priority) {
                ForEach(ReminderPriority.allCases, id: \.self) { p in
                    HStack {
                        Circle()
                            .fill(priorityColor(p))
                            .frame(width: 8, height: 8)
                        Text(p.displayName)
                    }
                    .tag(p)
                }
            } label: {
                Label("Öncelik", systemImage: "flag")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            TextField("Not (isteğe bağlı)", text: $notes)
                .font(AppTypography.body)
        } header: {
            Text("Öncelik ve Not")
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

    // MARK: - Helpers
    private func priorityColor(_ p: ReminderPriority) -> Color {
        switch p {
        case .info: return AppColors.accentPrimary
        case .warning: return AppColors.warning
        case .critical: return AppColors.critical
        }
    }

    // MARK: - Save
    private func saveReminder() {
        var errors: [String] = []

        if selectedTemplate == .custom && customTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Hatırlatıcı adı girmelisin.")
        }

        if selectedVehicleId == nil {
            errors.append("Bir araç seçmelisin.")
        }

        if !errors.isEmpty {
            validationErrors = errors
            return
        }

        guard let vehicleId = selectedVehicleId else { return }

        let dueOdometer = hasDueOdometer ? Int(dueOdometerText.sanitizedIntInput()) : nil

        if let existing = existingReminder {
            // Edit mode: mevcut kaydı güncelle
            existing.typeRaw = selectedTemplate.rawValue
            existing.title = displayTitle
            existing.dueDate = hasDueDate ? dueDate : nil
            existing.dueOdometer = dueOdometer
            existing.repeatRuleRaw = repeatRule == .none ? nil : repeatRule.rawValue
            existing.priorityRaw = priority.rawValue
            existing.vehicleId = vehicleId
            existing.notes = notes

            do {
                try modelContext.save()
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
                // Eski bildirimi iptal edip yenisini planla; retention bildirimlerini de yenile
                NotificationService.shared.cancelReminder(existing)
                Task { await VehicleContextRefreshService.refreshAfterVehicleContextChange(context: modelContext) }
                dismiss()
            } catch {
                modelContext.rollback()
                validationErrors = ["Kaydedilemedi: \(error.localizedDescription)"]
            }
        } else {
            // Insert mode: yeni kayıt oluştur
            let reminder = Reminder(
                vehicleId: vehicleId,
                type: selectedTemplate,
                title: displayTitle,
                dueDate: hasDueDate ? dueDate : nil,
                dueOdometer: dueOdometer,
                repeatRule: repeatRule == .none ? nil : repeatRule.rawValue,
                priority: priority,
                status: .active,
                notes: notes
            )
            modelContext.insert(reminder)
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
}

// MARK: - Preview
#Preview("Hatırlatıcı Ekleme") {
    ReminderFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
