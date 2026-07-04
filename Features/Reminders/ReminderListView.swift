import SwiftUI
import SwiftData

// MARK: - Reminder List View
// Gruplandırılmış hatırlatıcı listesi.
// Gruplar: Gecikenler → Bugün → Yaklaşanlar → Bu Yıl → Uzak Vade

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Reminder.dueDate) private var allReminders: [Reminder]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var showAddReminder = false
    @State private var notificationPermissionRequested = false

    var showHeader: Bool = true

    // Gruplandırılmış ve filtrelenmiş
    private var activeReminders: [Reminder] {
        allReminders.filter {
            $0.statusRaw != ReminderStatus.completed.rawValue &&
            $0.statusRaw != ReminderStatus.archived.rawValue
        }
    }

    private var overdueReminders: [Reminder] {
        activeReminders.filter { r in
            if r.isOverdue { return true }
            // Km eşiği geçilmiş olanlar da gecikenler grubuna
            if let vehicle = vehicleFor(r), r.isKmOverdue(vehicleOdometer: vehicle.currentOdometer) {
                return true
            }
            return false
        }
    }

    private var todayReminders: [Reminder] {
        activeReminders.filter { $0.isToday && !$0.isOverdue && !isKmOverdue($0) }
    }

    private var upcomingReminders: [Reminder] {
        activeReminders.filter { $0.isUpcoming && !$0.isToday && !$0.isOverdue && !isKmOverdue($0) }
    }

    /// 30-180 gün arası — "Bu Yıl" grubu
    private var midTermReminders: [Reminder] {
        activeReminders.filter {
            guard let dueDate = $0.dueDate, !$0.isOverdue, !$0.isToday, !$0.isUpcoming, !isKmOverdue($0) else { return false }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            return days > 30 && days <= 180
        }
    }

    /// 180+ gün — "Uzak Vade" grubu
    private var farFutureReminders: [Reminder] {
        activeReminders.filter {
            guard let dueDate = $0.dueDate, !$0.isOverdue, !$0.isToday, !$0.isUpcoming, !isKmOverdue($0) else { return false }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            return days > 180
        }
    }

    private func isKmOverdue(_ reminder: Reminder) -> Bool {
        guard let vehicle = vehicleFor(reminder) else { return false }
        return reminder.isKmOverdue(vehicleOdometer: vehicle.currentOdometer)
    }

    var body: some View {
        Group {
            if activeReminders.isEmpty {
                emptyState
            } else {
                reminderListContent
            }
        }
        .sheet(isPresented: $showAddReminder) { ReminderFormView() }
    }

    // MARK: - 30 Gün Özeti
    private var next30DaysCount: Int {
        activeReminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 999
            return days >= 0 && days <= 30
        }.count
    }

    private var overdueCount: Int { overdueReminders.count }
    private var todayCount: Int { todayReminders.count }

    // MARK: - Summary Module
    // 0/0/0 boş grid göstermek yerine pozitif özet — "her şey yolunda".
    @ViewBuilder
    private var summaryModule: some View {
        if overdueCount == 0 && todayCount == 0 && next30DaysCount == 0 {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundColor(AppColors.success)
                Text("Önümüzdeki 30 günde iş yok — her şey yolunda.")
                    .font(AppTypography.secondaryMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Önümüzdeki 30 günde iş yok, her şey yolunda.")
        } else {
            HStack(spacing: 0) {
                summaryItem(
                    count: overdueCount,
                    label: "Geciken",
                    icon: "exclamationmark.triangle.fill",
                    color: overdueCount > 0 ? AppColors.critical : AppColors.textTertiary
                )

                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 40)

                summaryItem(
                    count: todayCount,
                    label: "Bugün",
                    icon: "clock.fill",
                    color: todayCount > 0 ? AppColors.warning : AppColors.textTertiary
                )

                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 40)

                summaryItem(
                    count: next30DaysCount,
                    label: "30 Gün",
                    icon: "calendar.badge.clock",
                    color: next30DaysCount > 0 ? AppColors.accentPrimary : AppColors.textTertiary
                )
            }
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Önümüzdeki 30 gün: \(next30DaysCount) hatırlatıcı. Geciken: \(overdueCount). Bugün: \(todayCount).")
        }
    }

    private func summaryItem(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .monospacedDigit()
            }
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView(
            icon: "calendar.badge.clock",
            title: "Şu anda takip etmen gereken bir araç işi yok.",
            description: "Muayene, sigorta, bakım ve MTV gibi tarihleri ekleyerek aracını düzenli takip edebilirsin.",
            actionTitle: "Hatırlatıcı Ekle",
            action: { showAddReminder = true }
        )
    }

    // MARK: - List Content
    private var reminderListContent: some View {
        List {
            // Screen header description when used standalone (e.g. İşler tab)
            if showHeader {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Geciken, bugün ve yaklaşan araç işlerini öncelik sırasıyla takip et.")
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, AppSpacing.xxs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Üst özet modülü
            Section {
                summaryModule
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !overdueReminders.isEmpty {
                reminderGroup(
                    title: "Gecikenler",
                    icon: "exclamationmark.triangle.fill",
                    color: AppColors.critical,
                    reminders: overdueReminders
                )
            }

            if !todayReminders.isEmpty {
                reminderGroup(
                    title: "Bugün",
                    icon: "clock.fill",
                    color: AppColors.warning,
                    reminders: todayReminders
                )
            }

            if !upcomingReminders.isEmpty {
                reminderGroup(
                    title: "Yaklaşanlar",
                    icon: "bell.fill",
                    color: AppColors.accentPrimary,
                    reminders: upcomingReminders
                )
            }

            if !midTermReminders.isEmpty {
                reminderGroup(
                    title: "Bu Yıl",
                    icon: "calendar.badge.clock",
                    color: AppColors.accentPrimary.opacity(0.6),
                    reminders: midTermReminders
                )
            } else if !farFutureReminders.isEmpty {
                // Segmentasyon görünür kalsın: uzak vadeli iş varken ara grup boşsa
                // "Bu Yıl · 0" başlığı + sakin bilgi satırı göster.
                Section {
                    Text("30-180 gün aralığında planlı iş yok.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .listRowBackground(Color.appSurface)
                } header: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Text("Bu Yıl · 0")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            if !farFutureReminders.isEmpty {
                reminderGroup(
                    title: "Uzak Vade",
                    icon: "calendar",
                    color: AppColors.textTertiary,
                    reminders: farFutureReminders
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    // MARK: - Group Section
    private func reminderGroup(
        title: String,
        icon: String,
        color: Color,
        reminders: [Reminder]
    ) -> some View {
        Section {
            ForEach(reminders) { reminder in
                NavigationLink {
                    ReminderDetailView(
                        reminder: reminder,
                        vehicle: vehicleFor(reminder)
                    )
                } label: {
                    ReminderRow(reminder: reminder, vehicle: vehicleFor(reminder))
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        completeReminder(reminder)
                    } label: {
                        Label("Tamamla", systemImage: "checkmark")
                    }
                    .tint(AppColors.success)
                }
                .swipeActions(edge: .leading) {
                    Button(role: .destructive) {
                        deleteReminder(reminder)
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.medium)
                Text("· \(reminders.count)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .foregroundColor(color)
            .textCase(nil)
        }
    }

    // MARK: - Actions
    private func completeReminder(_ reminder: Reminder) {
        // Başarı haptik
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)

        // Tekrar kuralını tamamlamadan önce al (completedAt set edildikten sonra da erişilebilir).
        let rule = reminder.repeatRule
        let oldDueDate = reminder.dueDate
        let oldDueOdometer = reminder.dueOdometer

        reminder.statusRaw = ReminderStatus.completed.rawValue
        reminder.completedAt = Date()
        reminder.addedToHistoryAt = Date()
        try? modelContext.save()

        // Bildirimleri iptal et
        NotificationService.shared.cancelReminder(reminder)
        Task { await NotificationRefreshService.refreshAll(context: modelContext) }

        // Tekrarlayan hatırlatıcı ise bir sonraki oluşumu yarat
        if rule != .none, let baseDate = oldDueDate ?? reminder.completedAt {
            if let nextDate = ReminderRepeatEngine.shared.nextDueDate(from: baseDate, rule: rule) {
                let next = Reminder(
                    vehicleId: reminder.vehicleId,
                    type: reminder.type,
                    title: reminder.title,
                    dueDate: nextDate,
                    dueOdometer: oldDueOdometer,
                    repeatRule: reminder.repeatRuleRaw,
                    priority: reminder.priority,
                    status: .active,
                    notes: reminder.notes
                )
                modelContext.insert(next)
                try? modelContext.save()

                // Yeni oluşum ve retention bildirimleri için yenile
                Task {
                    await NotificationRefreshService.refreshAll(context: modelContext)
                }
            }
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        NotificationService.shared.cancelReminder(reminder)
        modelContext.delete(reminder)
        try? modelContext.save()
        Task { await NotificationRefreshService.refreshAll(context: modelContext) }
    }

    // MARK: - Helpers
    private func vehicleFor(_ reminder: Reminder) -> Vehicle? {
        vehicles.first { $0.id == reminder.vehicleId }
    }
}

// MARK: - Reminder Row
struct ReminderRow: View {
    let reminder: Reminder
    let vehicle: Vehicle?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Tip ikonu — daha belirgin araç bağlamı
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 38, height: 38)

                Image(systemName: reminder.type.defaultIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            // İçerik
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    // Araç plakası — otomotiv bağlamı
                    if let vehicle {
                        Image(systemName: "car.fill")
                            .font(.system(size: 8))
                            .foregroundColor(AppColors.textTertiary)
                        Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
            }

            Spacer(minLength: AppSpacing.sm)

            // Durum etiketi
            statusBadge
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), \(statusText)")
    }

    /// Öncelik/gecikme bazlı renk — 30+ gün kala hafif turkuaz ("uzak ama aktif")
    private var statusColor: Color {
        if reminder.isOverdue { return AppColors.critical }
        if let vehicle, reminder.isKmOverdue(vehicleOdometer: vehicle.currentOdometer) { return AppColors.critical }
        if reminder.isToday { return AppColors.warning }
        if let vehicle, reminder.isKmUpcoming(vehicleOdometer: vehicle.currentOdometer) { return AppColors.warning }
        if let dueDate = reminder.dueDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if days > 30 { return AppColors.accentPrimary.opacity(0.55) }
        }
        return AppColors.accentPrimary
    }

    /// Durum metni — tek kaynak, çiftlenme yok
    private var statusText: String {
        if reminder.isOverdue { return "\(reminder.daysOverdue) gün gecikti" }
        if let vehicle, reminder.isKmOverdue(vehicleOdometer: vehicle.currentOdometer) {
            let exceeded = vehicle.currentOdometer - (reminder.dueOdometer ?? 0)
            return "\(exceeded.formatted()) km gecikti"
        }
        if reminder.isToday { return "Bugün" }
        if let vehicle, reminder.isKmUpcoming(vehicleOdometer: vehicle.currentOdometer) {
            let remaining = (reminder.dueOdometer ?? 0) - vehicle.currentOdometer
            return "\(remaining.formatted()) km kaldı"
        }
        return "\(reminder.daysRemaining) gün kaldı"
    }

    /// Km tipi durumlar için özel rozet
    private var isKmBased: Bool {
        reminder.dueOdometer != nil
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isKmBased && !reminder.isOverdue && !reminder.isToday {
            // Km bazlı — daha teknik rozet
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 9, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(statusColor)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.1))
            )
        } else {
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.1))
                )
        }
    }
}

// MARK: - Preview
#Preview("Hatırlatıcı Listesi — Dolu") {
    ReminderListView()
        .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Hatırlatıcı Listesi — Dark Mode") {
    ReminderListView()
        .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Hatırlatıcı Listesi — Dinamik Tip") {
    ReminderListView()
        .modelContainer(MockDataProvider.previewContainer)
        .environment(\.dynamicTypeSize, .accessibility1)
}
