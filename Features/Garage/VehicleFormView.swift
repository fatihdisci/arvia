import SwiftUI
import SwiftData
import UIKit

// MARK: - Vehicle Form View
// Yeni araç ekleme formu. Sheet olarak sunulur.
// Design kurallarına uygun: token tabanlı spacing/renk, Türkçe metin, validasyon.

struct VehicleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: Required fields
    @State private var plate = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var odometerText = ""
    @State private var fuelType: FuelType = .gasoline
    @State private var usageType: VehicleUsageType = .personal
    @State private var transmissionType: TransmissionType = .automatic

    // MARK: Optional fields
    @State private var nickname = ""
    @State private var showPhotoPicker = false

    // MARK: First reminders (optional)
    @State private var addInspectionReminder = false
    @State private var inspectionDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()

    @State private var addInsuranceReminder = false
    @State private var insuranceDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var addCascoReminder = false
    @State private var cascoDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var addLastServiceReminder = false
    @State private var lastServiceDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var lastServiceOdometerText = ""

    // MARK: Validation
    @State private var validationErrors: [String] = []
    @State private var showErrors = false

    // MARK: Computed
    private var year: Int? { Int(yearText.trimmingCharacters(in: .whitespaces)) }
    private var odometer: Int? { Int(odometerText.trimmingCharacters(in: .whitespaces)) }
    private var lastServiceOdometer: Int? {
        let text = lastServiceOdometerText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : Int(text)
    }

    var body: some View {
        NavigationStack {
            Form {
                requiredSection
                optionalSection
                firstRemindersSection

                if showErrors && !validationErrors.isEmpty {
                    validationErrorsSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Araç Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: saveVehicle)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
        }
    }

    // MARK: - Required Section
    private var requiredSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Zorunlu Bilgiler")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.bottom, AppSpacing.xxs)

                formField(icon: "number", placeholder: "Plaka", text: $plate, keyboardType: .default)
                    .textInputAutocapitalization(.characters)
                formField(icon: "car", placeholder: "Marka", text: $brand)
                formField(icon: "tag", placeholder: "Model", text: $model)
                formField(icon: "calendar", placeholder: "Yıl", text: $yearText, keyboardType: .numberPad)
                formField(icon: "gauge.with.needle", placeholder: "Güncel Km", text: $odometerText, keyboardType: .numberPad)
            }

            Picker(selection: $fuelType) {
                ForEach(FuelType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Yakıt Tipi", systemImage: "fuelpump")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            Picker(selection: $transmissionType) {
                ForEach(TransmissionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Vites", systemImage: "gearshift")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            Picker(selection: $usageType) {
                ForEach(VehicleUsageType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Kullanım", systemImage: "person")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
        } header: {
            Text("Araç Bilgileri")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Optional Section
    private var optionalSection: some View {
        Section {
            formField(icon: "heart", placeholder: "Takma ad (isteğe bağlı)", text: $nickname)

            // Foto placeholder
            Button {
                showPhotoPicker = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "camera")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppColors.backgroundSecondary)
                        )
                    Text("Araç fotoğrafı ekle (isteğe bağlı)")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(true) // MVP: Fotoğraf daha sonra eklenecek
        } header: {
            Text("İsteğe Bağlı")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - First Reminders Section
    private var firstRemindersSection: some View {
        Section {
            reminderToggle(
                icon: ReminderType.inspection.defaultIcon,
                title: "Muayene",
                isOn: $addInspectionReminder,
                date: $inspectionDate,
                hasOdometer: false
            )

            reminderToggle(
                icon: ReminderType.trafficInsurance.defaultIcon,
                title: "Trafik Sigortası",
                isOn: $addInsuranceReminder,
                date: $insuranceDate,
                hasOdometer: false
            )

            reminderToggle(
                icon: ReminderType.casco.defaultIcon,
                title: "Kasko",
                isOn: $addCascoReminder,
                date: $cascoDate,
                hasOdometer: false
            )

            VStack(spacing: AppSpacing.xs) {
                reminderToggle(
                    icon: ReminderType.periodicService.defaultIcon,
                    title: "Son Bakım",
                    isOn: $addLastServiceReminder,
                    date: $lastServiceDate,
                    hasOdometer: true
                )

                if addLastServiceReminder {
                    HStack(spacing: AppSpacing.md) {
                        Spacer().frame(width: 24)
                        TextField("Km (isteğe bağlı)", text: $lastServiceOdometerText)
                            .keyboardType(.numberPad)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .fill(AppColors.backgroundSecondary)
                            )
                    }
                    .padding(.leading, AppSpacing.xl)
                }
            }
        } header: {
            Text("İlk Önemli Tarihler (İsteğe Bağlı)")
        } footer: {
            Text("Bu tarihler için hatırlatıcı oluşturulur. Daha sonra istediğin zaman düzenleyebilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Validation Errors Section
    private var validationErrorsSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { error in
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.critical)
                    Text(LocalizedStringKey(error))
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.critical)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Düzeltilmesi Gerekenler")
                .foregroundColor(AppColors.critical)
        }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - Reminder Toggle Row
    private func reminderToggle(
        icon: String,
        title: String,
        isOn: Binding<Bool>,
        date: Binding<Date>,
        hasOdometer: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Toggle(isOn: isOn) {
                Label(title, systemImage: icon)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.accentPrimary)

            if isOn.wrappedValue {
                DatePicker(
                    "Tarih",
                    selection: date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(AppTypography.secondary)
                .padding(.leading, AppSpacing.xl)
            }
        }
    }

    // MARK: - Form Field
    private func formField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            TextField(placeholder, text: text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboardType)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - Save Action
    private func saveVehicle() {
        let errors = validate()

        if errors.isEmpty {
            performSave()
        } else {
            validationErrors = errors
            showErrors = true
        }
    }

    private func validate() -> [String] {
        var errors: [String] = []

        let trimmedPlate = plate.trimmingCharacters(in: .whitespaces)
        if trimmedPlate.isEmpty {
            errors.append("Plaka zorunludur.")
        } else if trimmedPlate.count < 6 {
            errors.append("Plaka geçerli bir plaka numarası olmalıdır.")
        }

        if brand.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Marka zorunludur.")
        }

        if model.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Model zorunludur.")
        }

        if let year {
            let currentYear = Calendar.current.component(.year, from: Date())
            if year < 1900 || year > currentYear + 1 {
                errors.append("Yıl 1900 ile \(currentYear + 1) arasında olmalıdır.")
            }
        }

        if let odometer {
            if odometer < 0 {
                errors.append("Km sıfırdan küçük olamaz.")
            }
        } else {
            errors.append("Güncel km zorunludur.")
        }

        if addLastServiceReminder, let serviceKm = lastServiceOdometer, serviceKm < 0 {
            errors.append("Son bakım km sıfırdan küçük olamaz.")
        }

        return errors
    }

    private func performSave() {
        let vehicle = Vehicle(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            plate: plate.trimmingCharacters(in: .whitespaces).uppercased(),
            brand: brand.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            year: year,
            fuelType: fuelType,
            transmissionType: transmissionType,
            currentOdometer: odometer ?? 0,
            usageType: usageType,
            notes: ""
        )
        modelContext.insert(vehicle)

        // İlk hatırlatıcıları oluştur
        createFirstReminders(for: vehicle.id)

        // Kaydet
        try? modelContext.save()

        // Başarı haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }

    private func createFirstReminders(for vehicleId: UUID) {
        if addInspectionReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .inspection,
                title: "Muayene",
                dueDate: inspectionDate,
                priority: .warning
            )
            modelContext.insert(r)
        }

        if addInsuranceReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .trafficInsurance,
                title: "Trafik Sigortası",
                dueDate: insuranceDate,
                priority: .warning
            )
            modelContext.insert(r)
        }

        if addCascoReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .casco,
                title: "Kasko",
                dueDate: cascoDate,
                priority: .warning
            )
            modelContext.insert(r)
        }

        if addLastServiceReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .periodicService,
                title: "Periyodik Bakım",
                dueDate: Calendar.current.date(byAdding: .year, value: 1, to: lastServiceDate),
                dueOdometer: lastServiceOdometer.map { $0 + 10000 },
                priority: .info
            )
            modelContext.insert(r)
        }
    }
}

// MARK: - Preview
#Preview("Araç Ekleme Formu") {
    VehicleFormView()
}

#Preview("Araç Ekleme Formu — Dark Mode") {
    VehicleFormView()
        .preferredColorScheme(.dark)
}
