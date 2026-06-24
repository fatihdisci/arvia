import SwiftUI
import SwiftData

// MARK: - Reminder Form View
// Hatırlatıcı ekleme sheet'i. Şablon seçimi, tarih/km, tekrar, öncelik, araç bağlantısı.

struct ReminderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    // Şablon
    @State private var selectedTemplate: ReminderType = .custom
    @State private var customTitle = ""

    // Tarih / Km
    @State private var dueDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var hasDueDate = true
    @State private var dueOdometerText = ""
    @State private var hasDueOdometer = false

    // Tekrar
    @State private var repeatRule: RepeatRule = .none

    // Öncelik
    @State private var priority: ReminderPriority = .warning

    // Araç
    @State private var selectedVehicleId: UUID?

    // Not
    @State private var notes = ""

    @State private var validationErrors: [String] = []

    enum RepeatRule: String, CaseIterable {
        case none = "Tekrar Yok"
        case monthly = "Her Ay"
        case quarterly = "3 Ayda Bir"
        case biannual = "6 Ayda Bir"
        case yearly = "Her Yıl"
        case custom = "Özel"

        var displayName: String { rawValue }
    }

    private var displayTitle: String {
        if selectedTemplate == .custom {
            return customTitle.isEmpty ? "Yeni Hatırlatıcı" : customTitle
        }
        return selectedTemplate.displayName
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
            .navigationTitle("Hatırlatıcı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle", action: saveReminder)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
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
                ForEach(ReminderType.allCases, id: \.self) { type in
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
                        .keyboardType(.numberPad)
                        .font(AppTypography.body)
                }
            }

            Picker(selection: $repeatRule) {
                ForEach(RepeatRule.allCases, id: \.self) { rule in
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

        guard let vehicleId = selectedVehicleId else {
            errors.append("Bir araç seçmelisin.")
            validationErrors = errors
            return
        }

        if !errors.isEmpty {
            validationErrors = errors
            return
        }

        let dueOdometer = hasDueOdometer ? Int(dueOdometerText.trimmingCharacters(in: .whitespaces)) : nil

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
        try? modelContext.save()

        // Bildirim planla
        Task {
            await NotificationService.shared.scheduleReminder(reminder)
        }

        dismiss()
    }
}

// MARK: - Preview
#Preview("Hatırlatıcı Ekleme") {
    ReminderFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
