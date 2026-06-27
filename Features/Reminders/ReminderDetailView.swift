import SwiftUI
import SwiftData

// MARK: - Yapılacak Detayı
// Tap ile açılan detay ekranı. Düzenle, tamamla, ertele, sil işlemleri.

struct ReminderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let reminder: Reminder
    let vehicle: Vehicle?
    let onCompleteWithRecord: ((Reminder, CompletionAction) -> Void)?

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCompletionOptions = false

    enum CompletionAction {
        case justComplete
        case createServiceRecord
        case addExpense
        case addDocument
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Status header
                statusHeader

                // Detay bilgileri
                detailsCard

                // Araç bilgisi
                if let vehicle {
                    vehicleCardView(vehicle)
                }

                // Aksiyon butonları
                actionsCard

                Spacer().frame(height: AppSpacing.xxl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle(reminder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(AppColors.accentPrimary)
                }
                .accessibilityLabel("Düzenle")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ReminderFormView()
        }
        .confirmationDialog("Yapılacak Silinsin mi?", isPresented: $showDeleteConfirmation) {
            Button("Sil", role: .destructive) { deleteReminder() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu yapılacak kalıcı olarak silinir. Bildirimler iptal edilir.")
        }
        .confirmationDialog("Bu işlemi nasıl tamamlamak istersin?", isPresented: $showCompletionOptions) {
            Button("Sadece Tamamlandı İşaretle") { complete(justComplete: true) }
            if isServiceType {
                Button("Bakım Kaydı Oluştur") { completeAndRecord(.createServiceRecord) }
            }
            Button("Masraf Ekle") { completeAndRecord(.addExpense) }
            Button("Belge Ekle") { completeAndRecord(.addDocument) }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tamamlanan işlemi Geçmiş'e ekleyerek aracının dosyasını daha eksiksiz tutabilirsin.")
        }
    }

    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: reminder.type.defaultIcon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(statusColor)
                .frame(width: 80, height: 80)
                .background(
                    Circle().fill(statusColor.opacity(0.1))
                )

            Text(statusText)
                .font(AppTypography.sectionTitle)
                .foregroundColor(statusColor)

            if let daysText = daysText {
                Text(daysText)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Detaylar")

            VStack(spacing: 0) {
                detailRow(icon: "tag", title: "Tür", value: reminder.type.displayName)
                if let dueDate = reminder.dueDate {
                    Divider().padding(.leading, 40)
                    detailRow(icon: "calendar", title: "Tarih", value: dueDate.formatted(date: .long, time: .omitted))
                }
                if let dueKm = reminder.dueOdometer {
                    Divider().padding(.leading, 40)
                    detailRow(icon: "gauge.with.needle", title: "Km", value: "\(dueKm.formatted()) km")
                }
                if reminder.repeatRule != .none {
                    Divider().padding(.leading, 40)
                    detailRow(icon: "repeat", title: "Tekrar", value: reminder.repeatRule.displayName)
                }
                Divider().padding(.leading, 40)
                detailRow(icon: "flag", title: "Öncelik", value: reminder.priority.displayName)
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface)
            )
            .subtleShadow()
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)
            Text(title)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Vehicle Card
    private func vehicleCardView(_ v: Vehicle) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: v.vehicleType == .motorcycle ? "bicycle" : "car")
                .foregroundColor(AppColors.vehicle)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.plate.isEmpty ? v.fullName : v.plate)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(v.fullName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface)
        )
        .subtleShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Actions Card
    private var actionsCard: some View {
        VStack(spacing: AppSpacing.sm) {
            if !isCompleted {
                Button {
                    showCompletionOptions = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Tamamlandı İşaretle")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.screenMarginH)
            }

            HStack(spacing: AppSpacing.md) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Düzenle", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Sil", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.destructive)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
    }

    // MARK: - Helpers
    private var isCompleted: Bool {
        reminder.statusRaw == ReminderStatus.completed.rawValue
    }

    private var isServiceType: Bool {
        let serviceTypes: Set<ReminderType> = [.periodicService, .oilChange, .tire, .battery, .brakes, .timingBelt, .chainMaintenance, .chainSprocketSet, .sparkPlug, .airFilter, .suspensionCheck]
        return serviceTypes.contains(reminder.type)
    }

    private var statusColor: Color {
        if isCompleted { return AppColors.success }
        if reminder.isOverdue { return AppColors.critical }
        if reminder.isToday { return AppColors.warning }
        return AppColors.accentPrimary
    }

    private var statusText: String {
        if isCompleted { return "Tamamlandı" }
        if reminder.isOverdue { return "Gecikti" }
        if reminder.isToday { return "Bugün" }
        return "Yaklaşıyor"
    }

    private var daysText: String? {
        if isCompleted { return nil }
        if reminder.isOverdue { return "\(reminder.daysOverdue) gün gecikti" }
        return "\(reminder.daysRemaining) gün kaldı"
    }

    // MARK: - Actions
    private func complete(justComplete: Bool) {
        completeReminder(reminder)
        dismiss()
    }

    private func completeAndRecord(_ action: CompletionAction) {
        completeReminder(reminder)
        onCompleteWithRecord?(reminder, action)
        dismiss()
    }

    private func completeReminder(_ reminder: Reminder) {
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        let rule = reminder.repeatRule
        let oldDueDate = reminder.dueDate
        let oldDueOdometer = reminder.dueOdometer
        reminder.statusRaw = ReminderStatus.completed.rawValue
        reminder.completedAt = Date()
        try? modelContext.save()
        NotificationService.shared.cancelReminder(reminder)

        if rule != .none, let baseDate = oldDueDate ?? reminder.completedAt {
            if let nextDate = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: rule) {
                let next = Reminder(
                    vehicleId: reminder.vehicleId, type: reminder.type,
                    title: reminder.title, dueDate: nextDate,
                    dueOdometer: oldDueOdometer, repeatRule: reminder.repeatRuleRaw,
                    priority: reminder.priority, status: .active, notes: reminder.notes
                )
                modelContext.insert(next)
                try? modelContext.save()
                Task { await NotificationService.shared.scheduleReminder(next) }
            }
        }
    }

    private func deleteReminder() {
        NotificationService.shared.cancelReminder(reminder)
        modelContext.delete(reminder)
        try? modelContext.save()
        dismiss()
    }
}

#Preview("Yapılacak Detayı") {
    NavigationStack {
        ReminderDetailView(
            reminder: Reminder(vehicleId: UUID(), type: .inspection, title: "Muayene", dueDate: Date().addingTimeInterval(86400 * 5)),
            vehicle: nil,
            onCompleteWithRecord: nil
        )
    }
}
