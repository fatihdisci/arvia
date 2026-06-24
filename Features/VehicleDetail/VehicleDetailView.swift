import SwiftUI
import SwiftData

// MARK: - Vehicle Detail View
// Aracın ana dashboard ekranı.
// Tasarım kuralı: Tek görsel çapa (VehicleHeroHeader).
// Kartlar yalnızca anlamlıysa kullanılır — kart mozaik yok.

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    @Query private var allReminders: [Reminder]
    @Query private var allExpenses: [Expense]
    @Query private var allServiceRecords: [ServiceRecord]
    @Query private var allInspectionReports: [InspectionReport]

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showArchiveConfirmation = false
    @State private var showAddInspection = false
    @State private var showSaleFile = false

    // Filtered data
    private var reminders: [Reminder] {
        allReminders.filter { $0.vehicleId == vehicle.id }
    }

    private var expenses: [Expense] {
        allExpenses.filter { $0.vehicleId == vehicle.id }
    }

    private var serviceRecords: [ServiceRecord] {
        allServiceRecords.filter { $0.vehicleId == vehicle.id }
    }

    private var inspectionReports: [InspectionReport] {
        allInspectionReports.filter { $0.vehicleId == vehicle.id }
            .sorted { $0.reportDate > $1.reportDate }
    }

    private var activeReminders: [Reminder] {
        reminders.filter { $0.statusRaw != ReminderStatus.completed.rawValue && $0.statusRaw != ReminderStatus.archived.rawValue }
    }

    // Most critical upcoming task
    private var mostCriticalReminder: Reminder? {
        if let overdue = activeReminders.first(where: { $0.isOverdue }) { return overdue }
        if let today = activeReminders.first(where: { $0.isToday }) { return today }
        return activeReminders
            .filter { $0.dueDate != nil }
            .min(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // MARK: Visual Anchor — Hero Header
                VehicleHeroHeader(vehicle: vehicle)

                // MARK: Most Important Task
                if let reminder = mostCriticalReminder {
                    UpcomingTaskCard(reminder: reminder)
                        .padding(.horizontal, AppSpacing.screenMarginH)
                } else {
                    upcomingTaskEmptyState
                }

                // MARK: File Completeness
                fileCompletenessCard
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Inspection Report
                inspectionReportSection
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Recent Records
                recentRecordsSection

                // MARK: Vehicle Life Timeline
                lifeTimelineSection

                Spacer().frame(height: AppSpacing.xxl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle(vehicle.nickname.isEmpty ? vehicle.fullName : vehicle.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showSaleFile = true
                    } label: {
                        Label("Satış Dosyası", systemImage: "doc.richtext")
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }

                    if vehicle.archivedAt == nil {
                        Button {
                            showArchiveConfirmation = true
                        } label: {
                            Label("Arşivle", systemImage: "archivebox")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Aracı Sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel("Araç İşlemleri")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleEditView(vehicle: vehicle)
        }
        .sheet(isPresented: $showAddInspection) {
            InspectionReportFormView()
        }
        .sheet(isPresented: $showSaleFile) {
            SaleFileView(vehicle: vehicle)
        }
        .confirmationDialog("Aracı Arşivle", isPresented: $showArchiveConfirmation) {
            Button("Arşivle") { archiveVehicle() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Arşivlenen araç listede görünmez ama verileri silinmez. İstediğin zaman geri alabilirsin.")
        }
        .confirmationDialog("Aracı Sil", isPresented: $showDeleteConfirmation) {
            Button("Aracı ve Tüm Kayıtlarını Sil", role: .destructive) { deleteVehicle() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz. Araca ait tüm hatırlatıcılar, masraflar, bakım kayıtları, belgeler ve ekspertiz raporları kalıcı olarak silinir.")
        }
    }

    // MARK: - Upcoming Task Empty State
    private var upcomingTaskEmptyState: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundColor(AppColors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tüm işler tamam")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text("Yaklaşan bir iş görünmüyor.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - File Completeness Card
    private var fileCompletenessCard: some View {
        let score = computeFileScore()

        return HStack(spacing: AppSpacing.md) {
            // Skor halkası
            ZStack {
                Circle()
                    .stroke(scoreColor(score).opacity(0.2), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: score)

                Text("%\(score)")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(scoreColor(score))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Dosya Tamlığı")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(scoreDescription(score))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
    }

    // MARK: - Inspection Report Card
    private var inspectionReportSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let latest = inspectionReports.first {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundColor(AppColors.accentPrimary)
                        Text("Ekspertiz Raporu")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if latest.verificationStatus == .verified {
                            Label("Doğrulandı", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.success)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(latest.providerName)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textPrimary)
                        if let branch = latest.branchName, !branch.isEmpty {
                            Text(branch)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Text("\(latest.dateDisplay)\(latest.odometerDisplay.map { " · \($0)" } ?? "")")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    if !latest.summary.isEmpty {
                        Text(latest.summary)
                            .font(AppTypography.secondarySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(3)
                    }

                    // Hukuki uyarı
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                        Text(InspectionReport.legalDisclaimer)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(2)
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .subtleShadow()
            } else {
                // Ekspertiz yok — ekleme çağrısı
                Button {
                    showAddInspection = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ekspertiz raporu ekle")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("Aracının ekspertiz raporunu ekleyerek satış dosyanı güçlendir.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(Color.appSurface)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recent Records Section
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Son Kayıtlar",
                actionTitle: expenses.isEmpty && serviceRecords.isEmpty ? nil : "Tümü",
                action: {}
            )

            if expenses.isEmpty && serviceRecords.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                    Text("Henüz kayıt yok. Masraf veya bakım ekleyerek başlayabilirsin.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.appSurface)
                )
                .padding(.horizontal, AppSpacing.screenMarginH)
            } else {
                // Son 3 kayıt (masraf + bakım karışık, tarihe göre)
                let recentItems = recentRecords()
                ForEach(recentItems.prefix(3)) { item in
                    recentRecordRow(item)
                }
            }
        }
    }

    private func recentRecords() -> [RecentRecordItem] {
        var items: [RecentRecordItem] = []

        for expense in expenses {
            items.append(RecentRecordItem(
                id: expense.id,
                type: .expense,
                title: expense.category.displayName,
                subtitle: expense.amountCompactDisplay,
                date: expense.date,
                icon: expense.category.defaultIcon
            ))
        }

        for service in serviceRecords {
            items.append(RecentRecordItem(
                id: service.id,
                type: .service,
                title: service.serviceType.displayName,
                subtitle: service.vendorName ?? service.totalCostDisplay ?? "",
                date: service.date,
                icon: "wrench.and.screwdriver"
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private func recentRecordRow(_ item: RecentRecordItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                Text(item.subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(item.date.formatted(date: .numeric, time: .omitted))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Vehicle Life Timeline
    // Aracın kronolojik yaşam çizgisi — uygulamanın imza etkileşimi.
    private var lifeTimelineSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Araç Yaşam Çizgisi")

            VStack(spacing: 0) {
                let events = buildTimelineEvents()
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    timelineItem(
                        event: event,
                        isFirst: index == 0,
                        isLast: index == events.count - 1
                    )
                }

                if events.isEmpty {
                    timelineItem(
                        event: TimelineEvent(
                            id: UUID(),
                            icon: "car",
                            title: "Henüz kayıt yok",
                            date: nil,
                            isMilestone: false,
                            subtitle: nil
                        ),
                        isFirst: true,
                        isLast: true
                    )
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(Color.appSurface)
            )
            .subtleShadow()
            .padding(.horizontal, AppSpacing.screenMarginH)

            if serviceRecords.isEmpty {
                Text("Bakım ve masraf kayıtlarını ekledikçe aracının yaşam çizgisi burada şekillenecek.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.screenMarginH + AppSpacing.md)
            }
        }
    }

    private struct TimelineEvent: Identifiable {
        let id: UUID
        let icon: String
        let title: String
        let date: Date?
        let isMilestone: Bool
        let subtitle: String?
    }

    private func buildTimelineEvents() -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        // Satın alma
        if let purchaseDate = vehicle.purchaseDate {
            events.append(TimelineEvent(
                id: UUID(),
                icon: "cart",
                title: "Satın Alma",
                date: purchaseDate,
                isMilestone: true,
                subtitle: vehicle.purchasePriceDisplay
            ))
        }

        // Kilometre taşları — servis kayıtları (tarihe göre eskiden yeniye)
        let sortedServices = serviceRecords.sorted { ($0.date) < ($1.date) }
        for service in sortedServices.prefix(10) {
            events.append(TimelineEvent(
                id: service.id,
                icon: "wrench.and.screwdriver",
                title: service.serviceType.displayName,
                date: service.date,
                isMilestone: false,
                subtitle: service.vendorName ?? service.totalCostDisplay
            ))
        }

        // Önemli masraflar (büyük tutarlı, sadece 1000₺ üzeri)
        let majorExpenses = expenses
            .filter { $0.amount >= 1000 }
            .sorted { $0.date < $1.date }
            .prefix(5)
        for expense in majorExpenses {
            events.append(TimelineEvent(
                id: expense.id,
                icon: expense.category.defaultIcon,
                title: expense.category.displayName,
                date: expense.date,
                isMilestone: false,
                subtitle: expense.amountCompactDisplay
            ))
        }

        // Tarihe göre sırala (eskiden yeniye)
        events.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        return events
    }

    private func timelineItem(
        event: TimelineEvent,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Timeline çizgi + nokta
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(event.isMilestone ? AppColors.accentPrimary.opacity(0.3) : AppColors.border)
                        .frame(width: 2, height: 14)
                } else {
                    Spacer().frame(height: 4)
                }

                Circle()
                    .fill(event.isMilestone ? AppColors.accentPrimary : AppColors.border)
                    .frame(width: event.isMilestone ? 12 : 8, height: event.isMilestone ? 12 : 8)
                    .overlay(
                        event.isMilestone ?
                        Circle().stroke(AppColors.accentPrimary.opacity(0.3), lineWidth: 3) : nil
                    )

                if !isLast {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(width: 2, height: 14)
                } else {
                    Spacer().frame(height: 4)
                }
            }

            // İçerik
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(event.isMilestone ? AppTypography.bodyMedium : AppTypography.secondary)
                    .foregroundColor(event.isMilestone ? AppColors.accentPrimary : AppColors.textPrimary)

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let date = event.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()
        }
        .frame(minHeight: AppSpacing.minimumTapTarget)
    }

    // MARK: - Score Helpers
    private func computeFileScore() -> Int {
        var score = 0
        if !vehicle.brand.isEmpty { score += 10 }
        if !vehicle.model.isEmpty { score += 10 }
        if vehicle.year != nil { score += 10 }
        if vehicle.currentOdometer > 0 { score += 10 }
        if vehicle.transmissionType != nil { score += 10 }
        if vehicle.purchaseDate != nil { score += 10 }
        if vehicle.purchasePrice != nil { score += 10 }
        if !reminders.isEmpty { score += 15 }
        if !activeReminders.contains(where: { $0.isOverdue }) { score += 15 }
        if !expenses.isEmpty { score += 5 }
        if !serviceRecords.isEmpty { score += 5 }
        return min(score, 100)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return AppColors.warning }
        return AppColors.critical
    }

    private func scoreDescription(_ score: Int) -> String {
        if score >= 80 { return "Aracının dosyası oldukça tam." }
        if score >= 50 { return "Birkaç bilgi daha ekleyebilirsin." }
        return "Dosyanı tamamlamak için bilgi ekle."
    }

    // MARK: - Archive / Delete
    private func archiveVehicle() {
        vehicle.archivedAt = Date()
        try? modelContext.save()
        dismiss()
    }

    private func deleteVehicle() {
        // Tüm ilişkili verileri sil
        for reminder in reminders { modelContext.delete(reminder) }
        for expense in expenses { modelContext.delete(expense) }
        for service in serviceRecords { modelContext.delete(service) }

        // PartChange'leri sil (serviceRecordId ile bağlı)
        let allParts = (try? modelContext.fetch(FetchDescriptor<PartChange>())) ?? []
        for part in allParts where serviceRecords.contains(where: { $0.id == part.serviceRecordId }) {
            modelContext.delete(part)
        }

        // Belgeleri sil
        let allDocs = (try? modelContext.fetch(FetchDescriptor<VehicleDocument>())) ?? []
        for doc in allDocs where doc.vehicleId == vehicle.id {
            modelContext.delete(doc)
        }

        // Ekspertiz raporlarını sil
        let allInspections = (try? modelContext.fetch(FetchDescriptor<InspectionReport>())) ?? []
        for inspection in allInspections where inspection.vehicleId == vehicle.id {
            modelContext.delete(inspection)
        }

        // Satış dosyalarını sil
        let allSales = (try? modelContext.fetch(FetchDescriptor<SaleFile>())) ?? []
        for sale in allSales where sale.vehicleId == vehicle.id {
            modelContext.delete(sale)
        }

        modelContext.delete(vehicle)
        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        dismiss()
    }
}

// MARK: - Upcoming Task Card
struct UpcomingTaskCard: View {
    let reminder: Reminder

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // İkon
            Image(systemName: reminder.type.defaultIcon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(statusColor.opacity(0.12))
                )

            // İçerik
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(statusColor)

                Text(reminder.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                if let dueDate = reminder.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            // Kalan gün
            if reminder.isOverdue {
                Text("\(reminder.daysOverdue) gün")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.critical)
            } else if reminder.isToday {
                Text("Bugün")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.warning)
            } else {
                Text("\(reminder.daysRemaining) gün")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusTitle): \(reminder.title), \(statusText)")
    }

    private var statusColor: Color {
        if reminder.isOverdue { return AppColors.critical }
        if reminder.isToday { return AppColors.warning }
        return AppColors.accentPrimary
    }

    private var statusTitle: String {
        if reminder.isOverdue { return "Gecikmiş İş" }
        if reminder.isToday { return "Bugün" }
        return "Yaklaşan İş"
    }

    private var statusText: String {
        if reminder.isOverdue { return "\(reminder.daysOverdue) gün gecikti" }
        if reminder.isToday { return "Bugün" }
        return "\(reminder.daysRemaining) gün kaldı"
    }
}

// MARK: - Recent Record Item
struct RecentRecordItem: Identifiable {
    let id: UUID
    let type: RecordType
    let title: String
    let subtitle: String
    let date: Date
    let icon: String

    enum RecordType {
        case expense
        case service
    }
}

// MARK: - Preview
#Preview("Araç Detay — Dolu Veri") {
    let vehicle = MockDataProvider.previewVehicle()
    return NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
    }
}

#Preview("Araç Detay — Dark Mode") {
    let vehicle = MockDataProvider.previewVehicle()
    return NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
    }
    .preferredColorScheme(.dark)
}
