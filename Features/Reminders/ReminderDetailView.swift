import SwiftUI
import SwiftData

// MARK: - Yapılacak Detayı
// Tap ile açılan detay ekranı. Düzenle, tamamla, ertele, sil işlemleri.

struct ReminderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let reminder: Reminder
    let vehicle: Vehicle?

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCompletionOptions = false
    @State private var showSnoozeSheet = false
    @State private var snoozeDays = 7
    @State private var operationError: String?
    // Bakım tipi bir iş tamamlandığında "bakım kaydı oluştur" önerisi.
    @State private var showServiceConversionPrompt = false
    @State private var showServiceForm = false

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

                Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
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
            ReminderFormView(existingReminder: reminder)
        }
        .confirmationDialog("Yapılacak Silinsin mi?", isPresented: $showDeleteConfirmation) {
            Button("Sil", role: .destructive) { deleteReminder() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu yapılacak kalıcı olarak silinir. Bildirimler iptal edilir.")
        }
        .confirmationDialog("Yapılacak tamamlansın mı?", isPresented: $showCompletionOptions) {
            Button("Tamamla ve Geçmişe Ekle") { completeAndAddToHistory() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu iş tamamlandı olarak işaretlenir ve Geçmiş ekranında görünür.")
        }
        .confirmationDialog("Bakımı kayıtlarına ekleyelim mi?", isPresented: $showServiceConversionPrompt) {
            Button("Bakım Kaydı Oluştur") { showServiceForm = true }
            Button("Şimdi Değil", role: .cancel) { dismiss() }
        } message: {
            Text("Yaptığın bakımı kayıtlarına ekleyerek geçmişini ve maliyetini takip edebilirsin.")
        }
        .sheet(isPresented: $showServiceForm, onDismiss: { dismiss() }) {
            ServiceRecordFormView(preselectedVehicleId: reminder.vehicleId)
        }
        .sheet(isPresented: $showSnoozeSheet) {
            snoozeSheet
        }
        .alert("İşlem Tamamlanamadı", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(operationError ?? "Bilinmeyen bir hata oluştu.")
        }
    }

    // MARK: - Snooze Sheet
    private var snoozeSheet: some View {
        VStack(spacing: AppSpacing.md) {
            // Header
            VStack(spacing: AppSpacing.xxs) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.title2)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(AppColors.accentPrimary.opacity(0.1))
                    )

                Text("Kaç gün ertelemek istersin?")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.top, AppSpacing.md)

            // Day Picker — wheel
            Picker("Gün", selection: $snoozeDays) {
                ForEach([1, 3, 7, 14, 30], id: \.self) { days in
                    Text("\(days) gün").tag(days)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
            .clipped()

            // Preview
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text("Yeni tarih: \(snoozePreviewDate)")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, AppSpacing.xs)

            Divider()

            // Actions
            HStack(spacing: AppSpacing.sm) {
                Button("Vazgeç") {
                    showSnoozeSheet = false
                }
                .buttonStyle(.secondary)
                .frame(maxWidth: .infinity)

                Button {
                    snoozeReminder()
                    showSnoozeSheet = false
                } label: {
                    Text("Ertele")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .presentationDetents([.height(400)])
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
            .cardShadow()
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
            Image(systemName: v.vehicleType.heroSymbol)
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
        .cardShadow()
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
                        Text("Tamamla ve Geçmişe Ekle")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.screenMarginH)

                Button {
                    showSnoozeSheet = true
                } label: {
                    HStack {
                        Image(systemName: "clock.badge")
                        Text("Ertele")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
                .padding(.horizontal, AppSpacing.screenMarginH)
                .accessibilityLabel("Ertele")
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

    // MARK: - Snooze

    private var snoozePreviewDate: String {
        let preview = Reminder.snoozedDueDate(currentDueDate: reminder.dueDate, days: snoozeDays)
        return preview.formatted(date: .long, time: .omitted)
    }

    private func snoozeReminder() {
        let newDate = Reminder.snoozedDueDate(currentDueDate: reminder.dueDate, days: snoozeDays)
        reminder.dueDate = newDate
        do {
            try modelContext.save()
            NotificationService.shared.cancelReminder(reminder)
            Task { await NotificationService.shared.scheduleReminder(reminder) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            modelContext.rollback()
            operationError = "Yapılacak ertelenemedi. Verileriniz değiştirilmedi."
        }
    }

    // MARK: - Helpers
    private var isCompleted: Bool {
        reminder.statusRaw == ReminderStatus.completed.rawValue
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

    /// Tamamlama her zaman completedAt ve addedToHistoryAt set eder; HistoryView'da görünür.
    private func completeAndAddToHistory() {
        let rule = reminder.repeatRule
        let oldDueDate = reminder.dueDate
        let oldDueOdometer = reminder.dueOdometer
        reminder.completeAndAddToHistory()
        var nextReminder: Reminder?

        if rule != .none, let baseDate = oldDueDate ?? reminder.completedAt {
            if let nextDate = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: rule) {
                let next = Reminder(
                    vehicleId: reminder.vehicleId, type: reminder.type,
                    title: reminder.title, dueDate: nextDate,
                    dueOdometer: oldDueOdometer, repeatRule: reminder.repeatRuleRaw,
                    priority: reminder.priority, status: .active, notes: reminder.notes
                )
                modelContext.insert(next)
                nextReminder = next
            }
        }

        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            NotificationService.shared.cancelReminder(reminder)
            if let nextReminder {
                Task { await NotificationService.shared.scheduleReminder(nextReminder) }
            }
            // Bakım tipi bir iş tamamlandıysa (yağ, fren, periyodik bakım vb.)
            // kullanıcıya bunu bir bakım kaydına dönüştürmeyi öner. Diğer türlerde
            // (muayene, sigorta, MTV...) doğrudan kapat.
            if reminder.type.mapsToServiceRecord {
                showServiceConversionPrompt = true
            } else {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            operationError = "Yapılacak tamamlanamadı. Verileriniz değiştirilmedi."
        }
    }

    private func deleteReminder() {
        let reminderID = reminder.id
        modelContext.delete(reminder)
        do {
            try modelContext.save()
            NotificationService.shared.cancelReminder(id: reminderID)
            dismiss()
        } catch {
            modelContext.rollback()
            operationError = "Yapılacak silinemedi. Verileriniz değiştirilmedi."
        }
    }
}

#Preview("Yapılacak Detayı") {
    NavigationStack {
        ReminderDetailView(
            reminder: Reminder(vehicleId: UUID(), type: .inspection, title: "Muayene", dueDate: Date().addingTimeInterval(86400 * 5)),
            vehicle: nil
        )
    }
}
