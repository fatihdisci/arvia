import Foundation

// MARK: - Vehicle Insight Service
// Generates local, rule-based Arvia Rehber and daily context cards. No network or AI calls.

struct VehicleInsightService {
    static let shared = VehicleInsightService()
    static let defaultVisibleLimit = 3

    let calendar: Calendar
    private let fixedNow: Date?

    private var now: Date { fixedNow ?? Date() }

    init(calendar: Calendar = .current, now: Date? = nil) {
        self.calendar = calendar
        self.fixedNow = now
    }

    func insights(
        for vehicle: Vehicle,
        reminders: [Reminder],
        expenses: [Expense],
        serviceRecords: [ServiceRecord],
        documents: [VehicleDocument],
        inspectionReports: [InspectionReport],
        saleFiles: [SaleFile] = [],
        maxVisible: Int = Self.defaultVisibleLimit,
        displayContext: VehicleInsightDisplayContext = .vehicleDetailGuide()
    ) -> [VehicleInsight] {
        Array(contextualInsights(
            for: vehicle,
            reminders: reminders,
            expenses: expenses,
            serviceRecords: serviceRecords,
            documents: documents,
            inspectionReports: inspectionReports,
            includeQuietState: true,
            displayContext: displayContext
        ).prefix(maxVisible))
    }

    func garageSummary(
        for vehicle: Vehicle,
        reminders: [Reminder],
        expenses: [Expense],
        serviceRecords: [ServiceRecord],
        documents: [VehicleDocument],
        inspectionReports: [InspectionReport],
        maxVisible: Int = Self.defaultVisibleLimit
    ) -> [VehicleInsight] {
        Array(contextualInsights(
            for: vehicle,
            reminders: reminders,
            expenses: expenses,
            serviceRecords: serviceRecords,
            documents: documents,
            inspectionReports: inspectionReports,
            includeQuietState: true,
            displayContext: .garageDaily
        ).prefix(maxVisible))
    }

    func monthlySummary(expenses: [Expense]) -> MonthlyExpenseSummary {
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let monthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }
        let total = monthExpenses.reduce(0) { $0 + $1.amount }
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in monthExpenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }
        let topCategory = categoryTotals.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.displayName < rhs.key.displayName
            }
            return lhs.value < rhs.value
        }?.key
        return MonthlyExpenseSummary(total: total, count: monthExpenses.count, topCategory: topCategory)
    }

    func formattedTRY(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = amount.rounded() == amount ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "₺\(String(format: "%.0f", amount))"
    }

    func upcomingTasks(
        reminders: [Reminder],
        vehicleOdometer: Int,
        limit: Int = 3
    ) -> [VehicleUpcomingTask] {
        Array(reminders
            .filter { isActive($0) && (isDateRelevant($0) || isKmRelevant($0, vehicleOdometer: vehicleOdometer)) }
            .sorted { lhs, rhs in
                reminderSortRank(lhs, vehicleOdometer: vehicleOdometer) < reminderSortRank(rhs, vehicleOdometer: vehicleOdometer)
            }
            .prefix(limit)
            .map { reminder in
                VehicleUpcomingTask(
                    id: reminder.id,
                    title: reminder.title.isEmpty ? reminder.type.displayName : reminder.title,
                    relativeText: relativeDueText(for: reminder, vehicleOdometer: vehicleOdometer),
                    priority: taskPriority(for: reminder, vehicleOdometer: vehicleOdometer),
                    reminderId: reminder.id
                )
            })
    }

    func validateOdometerInput(_ rawValue: String, currentOdometer: Int, allowLowerValue: Bool) -> QuickOdometerValidationResult {
        let trimmed = rawValue.sanitizedIntInput()
        guard !trimmed.isEmpty else { return .empty }
        guard let value = Int(trimmed) else { return .invalid }
        guard value >= 0 else { return .negative }
        if value < currentOdometer && !allowLowerValue {
            return .lowerNeedsConfirmation
        }
        return .valid
    }

    func parsedOdometer(_ rawValue: String) -> Int? {
        Int(rawValue.sanitizedIntInput())
    }

    private func contextualInsights(
        for vehicle: Vehicle,
        reminders: [Reminder],
        expenses: [Expense],
        serviceRecords: [ServiceRecord],
        documents: [VehicleDocument],
        inspectionReports: [InspectionReport],
        includeQuietState: Bool,
        displayContext: VehicleInsightDisplayContext
    ) -> [VehicleInsight] {
        var generated: [VehicleInsight] = []

        generated.append(contentsOf: overdueReminderInsights(reminders, vehicleOdometer: vehicle.currentOdometer))
        if let upcoming = upcomingReminderInsight(reminders, vehicleOdometer: vehicle.currentOdometer) {
            generated.append(upcoming)
        }
        if let calendarInsight = calendarPeriodInsight() {
            generated.append(calendarInsight)
        }
        if let odometerInsight = odometerUpdateInsight(for: vehicle, expenses: expenses, serviceRecords: serviceRecords, inspectionReports: inspectionReports) {
            generated.append(odometerInsight)
        }
        if let seasonal = seasonalGuidanceInsight() {
            generated.append(seasonal)
        }
        generated.append(contentsOf: profileGuidanceInsights(for: vehicle))
        if let milestone = odometerMilestoneInsight(for: vehicle, serviceRecords: serviceRecords, reminders: reminders) {
            generated.append(milestone)
        }
        if documents.isEmpty {
            generated.append(noDocumentInsight())
        }
        if monthlySummary(expenses: expenses).isEmpty {
            generated.append(monthlyExpensePromptInsight())
        }
        if serviceRecords.isEmpty {
            generated.append(noServiceRecordInsight())
        } else if let latestService = serviceRecords.max(by: { $0.date < $1.date }),
                  isOlderThanMonths(latestService.date, months: 12) {
            generated.append(oldServiceRecordInsight())
        }
        if generated.isEmpty && includeQuietState {
            generated.append(quietGoodStateInsight())
        }

        return deduplicated(filtered(generated, for: displayContext))
            .sorted { lhs, rhs in
                if insightRank(lhs) == insightRank(rhs) {
                    return lhs.title < rhs.title
                }
                return insightRank(lhs) < insightRank(rhs)
            }
    }

    private func filtered(_ insights: [VehicleInsight], for displayContext: VehicleInsightDisplayContext) -> [VehicleInsight] {
        switch displayContext {
        case .garageDaily:
            let dailyTypes: Set<VehicleInsightType> = [
                .overdueReminder,
                .upcomingReminder,
                .calendarPeriod,
                .odometerUpdate,
                .quietGoodState,
                .seasonalGuidance,
            ]
            let urgent = insights.filter { dailyTypes.contains($0.type) && $0.type != .seasonalGuidance }
            if urgent.isEmpty {
                return insights.filter { $0.type == .seasonalGuidance || $0.type == .quietGoodState }
            }
            return urgent
        case .vehicleDetailGuide(let excludingReminderIds):
            return insights.filter { insight in
                guard let reminderId = insight.relatedReminderId else { return true }
                return !excludingReminderIds.contains(reminderId)
            }
        }
    }

    private func overdueReminderInsights(_ reminders: [Reminder], vehicleOdometer: Int) -> [VehicleInsight] {
        reminders
            .filter { isActive($0) && (isDateOverdue($0) || $0.isKmOverdue(vehicleOdometer: vehicleOdometer)) }
            .sorted { reminderSortRank($0, vehicleOdometer: vehicleOdometer) < reminderSortRank($1, vehicleOdometer: vehicleOdometer) }
            .prefix(2)
            .map { reminder in
                VehicleInsight(
                    type: .overdueReminder,
                    priority: .important,
                    title: reminder.isKmOverdue(vehicleOdometer: vehicleOdometer) ? "Km sınırı geçen iş var" : "Geciken işi tamamla",
                    body: "\(reminder.title.isEmpty ? reminder.type.displayName : reminder.title) için kayıtlarına göre aksiyon gerekebilir.",
                    action: .openTodos,
                    relatedReminderId: reminder.id
                )
            }
    }

    private func upcomingReminderInsight(_ reminders: [Reminder], vehicleOdometer: Int) -> VehicleInsight? {
        guard let reminder = reminders
            .filter({ isActive($0) && (isTodayOrTomorrow($0) || isUpcomingWithinDays($0, days: 14) || $0.isKmUpcoming(vehicleOdometer: vehicleOdometer, withinKm: 1500)) })
            .sorted(by: { reminderSortRank($0, vehicleOdometer: vehicleOdometer) < reminderSortRank($1, vehicleOdometer: vehicleOdometer) })
            .first else { return nil }

        return VehicleInsight(
            type: .upcomingReminder,
            priority: .warning,
            title: "Yaklaşan iş var",
            body: "\(reminder.title.isEmpty ? reminder.type.displayName : reminder.title): \(relativeDueText(for: reminder, vehicleOdometer: vehicleOdometer)).",
            action: .openTodos,
            relatedReminderId: reminder.id
        )
    }

    private func odometerUpdateInsight(
        for vehicle: Vehicle,
        expenses: [Expense],
        serviceRecords: [ServiceRecord],
        inspectionReports: [InspectionReport]
    ) -> VehicleInsight? {
        if vehicle.currentOdometer <= 0 {
            return VehicleInsight(
                type: .odometerUpdate,
                priority: .warning,
                title: "Kilometre bilgisini güncelle",
                body: "Güncel kilometre, bakım ve masraf takibini daha doğru hale getirir.",
                action: .updateOdometer
            )
        }
        if shouldSuggestOdometerUpdate(expenses: expenses, serviceRecords: serviceRecords, inspectionReports: inspectionReports) {
            return VehicleInsight(
                type: .odometerUpdate,
                priority: .info,
                title: "Kilometreyi güncel tut",
                body: "Son km kayıtların eski görünüyor. Güncel km eklemek hatırlatıcıları daha anlamlı hale getirir.",
                action: .updateOdometer
            )
        }
        return nil
    }

    private func calendarPeriodInsight() -> VehicleInsight? {
        let month = calendar.component(.month, from: now)
        guard month == 1 || month == 7 else { return nil }
        return VehicleInsight(
            type: .calendarPeriod,
            priority: .warning,
            title: "MTV dönemindesin",
            body: "MTV dönemindesin. Kendi durumunu kontrol etmek ve hatırlatıcı eklemek isteyebilirsin.",
            action: .addMTVReminder
        )
    }

    private func seasonalGuidanceInsight() -> VehicleInsight? {
        let season = currentSeason()
        let body: String
        switch season {
        case .winter:
            body = "Kış döneminde lastik, antifriz, akü ve silecek görünürlük kontrollerini kayıt altında tutmak faydalı olabilir."
        case .spring:
            body = "Bahar döneminde klima, yaz öncesi genel kontrol ve süspansiyon kayıtlarını gözden geçirmek faydalı olabilir."
        case .summer:
            body = "Yaz döneminde klima, soğutma sistemi ve lastik basıncı kontrollerini kayıt altında tutmak faydalı olabilir."
        case .autumn:
            body = "Sonbaharda lastik, fren, akü, ısıtma ve görünürlük hazırlıklarını kayıt altında tutmak faydalı olabilir."
        }

        return VehicleInsight(
            type: .seasonalGuidance,
            priority: .info,
            title: season.title,
            body: body,
            action: .addReminder
        )
    }

    private func profileGuidanceInsights(for vehicle: Vehicle) -> [VehicleInsight] {
        var insights: [VehicleInsight] = []
        insights.append(fuelTypeInsight(for: vehicle.fuelType))
        if let transmissionType = vehicle.transmissionType {
            insights.append(transmissionInsight(for: transmissionType))
        }
        return insights
    }

    private func fuelTypeInsight(for fuelType: FuelType) -> VehicleInsight {
        let body: String
        switch fuelType {
        case .diesel:
            body = "Dizel araçlarda düzenli yağ, filtre ve yakıt filtresiyle ilgili bakım kayıtlarını takip etmek faydalı olabilir."
        case .gasoline:
            body = "Benzinli araçlarda yağ, filtre ve bujiyle ilgili bakım kayıtlarını düzenli tutmak faydalı olabilir."
        case .lpg:
            body = "LPG'li araçlarda LPG sistemi ve filtre kontrolünü uzman servis kaydıyla takip etmek faydalı olabilir."
        case .hybrid:
            body = "Hibrit araçlarda periyodik sistem ve batarya ile ilgili servis kayıtlarını ayrı tutmak faydalı olabilir."
        case .electric:
            body = "Elektrikli araçlarda periyodik sistem ve batarya ile ilgili servis kayıtlarını ayrı tutmak faydalı olabilir."
        }
        return VehicleInsight(
            type: .fuelTypeGuidance,
            priority: .info,
            title: "\(fuelType.displayName) için kayıt önerisi",
            body: body,
            action: .addServiceRecord
        )
    }

    private func transmissionInsight(for transmissionType: TransmissionType) -> VehicleInsight {
        let body: String
        switch transmissionType {
        case .automatic:
            body = "Otomatik vitesli araçlarda şanzıman bakım geçmişini kayıt altında tutmak faydalı olabilir."
        case .manual:
            body = "Manuel araçlarda debriyajla ilgili bakım ve masraf kayıtlarını ayrı tutmak kayıt düzenini güçlendirebilir."
        case .semiAutomatic:
            body = "Yarı otomatik araçlarda şanzıman ve debriyaj sistemiyle ilgili kayıtları ayrı tutmak faydalı olabilir."
        }
        return VehicleInsight(
            type: .transmissionGuidance,
            priority: .info,
            title: "\(transmissionType.displayName) vites kayıtları",
            body: body,
            action: .addServiceRecord
        )
    }

    private func odometerMilestoneInsight(for vehicle: Vehicle, serviceRecords: [ServiceRecord], reminders: [Reminder]) -> VehicleInsight? {
        guard vehicle.currentOdometer > 0 else { return nil }
        let thresholds = [10_000, 15_000, 20_000, 30_000, 60_000, 90_000, 120_000]
        guard let threshold = thresholds.first(where: { abs(vehicle.currentOdometer - $0) <= 1_000 }) else { return nil }
        let hasRecentService = serviceRecords.contains { service in
            if let odometer = service.odometer, abs(odometer - vehicle.currentOdometer) <= 5_000 { return true }
            return !isOlderThanMonths(service.date, months: 6)
        }
        let hasDueKmReminder = reminders.contains { isActive($0) && $0.isKmOverdue(vehicleOdometer: vehicle.currentOdometer) }
        guard !hasRecentService && !hasDueKmReminder else { return nil }

        return VehicleInsight(
            type: .odometerMilestone,
            priority: .info,
            title: "\(threshold.formatted()) km çevresi",
            body: "Bu km aralığında bakım kayıtlarını kontrol etmek faydalı olabilir.",
            action: .addServiceRecord
        )
    }

    private func monthlyExpensePromptInsight() -> VehicleInsight {
        VehicleInsight(
            type: .monthlyExpensePrompt,
            priority: .info,
            title: "Bu ay masraf kaydı yok",
            body: "Bu ay henüz masraf kaydı yok. Yakıt veya bakım masrafı eklemek istersen hızlı işlem kullanabilirsin.",
            action: .addExpense
        )
    }

    private func noServiceRecordInsight() -> VehicleInsight {
        VehicleInsight(
            type: .maintenance,
            priority: .info,
            title: "Bakım kayıtlarını düzenle",
            body: "Kayıtlarına göre bakım geçmişi eksik görünüyor. Genel bakım kayıtlarını eklemek faydalı olabilir.",
            action: .addServiceRecord
        )
    }

    private func oldServiceRecordInsight() -> VehicleInsight {
        VehicleInsight(
            type: .maintenance,
            priority: .warning,
            title: "Bakım geçmişini kontrol et",
            body: "Kayıtlarında son bakımın üzerinden uzun süre geçmiş görünüyor. Bakım geçmişini gözden geçirmek faydalı olabilir.",
            action: .addServiceRecord
        )
    }

    private func noDocumentInsight() -> VehicleInsight {
        VehicleInsight(
            type: .missingDocument,
            priority: .info,
            title: "Dosyana belge ekle",
            body: "Ruhsat, poliçe, muayene veya servis faturalarını ekleyerek aracının kayıtlarını daha düzenli tutabilirsin.",
            action: .addDocument
        )
    }

    private func quietGoodStateInsight() -> VehicleInsight {
        VehicleInsight(
            type: .quietGoodState,
            priority: .info,
            title: "Her şey yolunda görünüyor",
            body: "Her şey yolunda görünüyor. Yeni masraf, belge veya km bilgisi eklemek istersen hızlı işlemleri kullanabilirsin.",
            action: .addExpense
        )
    }

    private func shouldSuggestOdometerUpdate(
        expenses: [Expense],
        serviceRecords: [ServiceRecord],
        inspectionReports: [InspectionReport]
    ) -> Bool {
        let datedOdometerEvidence = [
            expenses.compactMap { $0.odometer == nil ? nil : $0.date },
            serviceRecords.compactMap { $0.odometer == nil ? nil : $0.date },
            inspectionReports.compactMap { $0.odometer == nil ? nil : $0.reportDate },
        ].flatMap { $0 }

        guard let latest = datedOdometerEvidence.max() else { return false }
        return isOlderThanMonths(latest, months: 6)
    }

    private func isOlderThanMonths(_ date: Date, months: Int) -> Bool {
        guard let threshold = calendar.date(byAdding: .month, value: -months, to: now) else { return false }
        return date < threshold
    }

    private func isActive(_ reminder: Reminder) -> Bool {
        reminder.statusRaw != ReminderStatus.completed.rawValue &&
        reminder.statusRaw != ReminderStatus.archived.rawValue
    }

    private func isDateOverdue(_ reminder: Reminder) -> Bool {
        guard let dueDate = reminder.dueDate else { return false }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now)
    }

    private func isTodayOrTomorrow(_ reminder: Reminder) -> Bool {
        guard let dueDate = reminder.dueDate else { return false }
        let startNow = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: startNow, to: dueDay).day ?? 999
        return days == 0 || days == 1
    }

    private func isUpcomingWithinDays(_ reminder: Reminder, days: Int) -> Bool {
        guard let dueDate = reminder.dueDate else { return false }
        let startNow = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        let remaining = calendar.dateComponents([.day], from: startNow, to: dueDay).day ?? 999
        return remaining > 0 && remaining <= days
    }

    private func isDateRelevant(_ reminder: Reminder) -> Bool {
        isDateOverdue(reminder) || isTodayOrTomorrow(reminder) || isUpcomingWithinDays(reminder, days: 30)
    }

    private func isKmRelevant(_ reminder: Reminder, vehicleOdometer: Int) -> Bool {
        reminder.isKmOverdue(vehicleOdometer: vehicleOdometer) || reminder.isKmUpcoming(vehicleOdometer: vehicleOdometer)
    }

    private func reminderSortRank(_ reminder: Reminder, vehicleOdometer: Int) -> (Int, Int, Date) {
        let bucket: Int
        if isDateOverdue(reminder) || reminder.isKmOverdue(vehicleOdometer: vehicleOdometer) {
            bucket = 0
        } else if isTodayOrTomorrow(reminder) {
            bucket = 1
        } else if isUpcomingWithinDays(reminder, days: 30) || reminder.isKmUpcoming(vehicleOdometer: vehicleOdometer) {
            bucket = 2
        } else {
            bucket = 3
        }
        return (bucket, -priorityRank(reminder.priority), reminder.dueDate ?? .distantFuture)
    }

    private func taskPriority(for reminder: Reminder, vehicleOdometer: Int) -> VehicleInsightPriority {
        if isDateOverdue(reminder) || reminder.isKmOverdue(vehicleOdometer: vehicleOdometer) { return .important }
        if isTodayOrTomorrow(reminder) || reminder.priority == .critical { return .warning }
        return .info
    }

    private func relativeDueText(for reminder: Reminder, vehicleOdometer: Int) -> String {
        if reminder.isKmOverdue(vehicleOdometer: vehicleOdometer) { return "Km sınırı geçti" }
        if let dueOdometer = reminder.dueOdometer {
            let remaining = dueOdometer - vehicleOdometer
            if remaining > 0 && remaining <= 2_000 { return "\(remaining.formatted()) km kaldı" }
        }
        guard let dueDate = reminder.dueDate else { return "Takipte" }
        let startNow = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: startNow, to: dueDay).day ?? 999
        if days < 0 { return "Gecikti" }
        if days == 0 { return "Bugün" }
        if days == 1 { return "Yarın" }
        return "\(days) gün kaldı"
    }

    private func priorityRank(_ priority: ReminderPriority) -> Int {
        switch priority {
        case .critical:
            return 3
        case .warning:
            return 2
        case .info:
            return 1
        }
    }

    private func insightRank(_ insight: VehicleInsight) -> Int {
        switch insight.type {
        case .overdueReminder:
            return 0
        case .upcomingReminder:
            return 1
        case .calendarPeriod:
            return 2
        case .odometerUpdate:
            return 3
        case .seasonalGuidance:
            return 4
        case .missingDocument, .fuelTypeGuidance, .transmissionGuidance, .odometerMilestone:
            return 5
        case .monthlyExpensePrompt:
            return 6
        case .maintenance:
            return 7
        case .saleFileReadiness:
            return 8
        case .quietGoodState:
            return 9
        }
    }

    private func deduplicated(_ insights: [VehicleInsight]) -> [VehicleInsight] {
        var seen: Set<String> = []
        var result: [VehicleInsight] = []
        for insight in insights where !seen.contains(insight.id) {
            seen.insert(insight.id)
            result.append(insight)
        }
        return result
    }

    private enum Season {
        case winter
        case spring
        case summer
        case autumn

        var title: String {
            switch self {
            case .winter: return "Kış hazırlığı"
            case .spring: return "Bahar kontrolü"
            case .summer: return "Yaz dönemi kontrolü"
            case .autumn: return "Sonbahar hazırlığı"
            }
        }
    }

    private func currentSeason() -> Season {
        switch calendar.component(.month, from: now) {
        case 12, 1, 2:
            return .winter
        case 3, 4, 5:
            return .spring
        case 6, 7, 8:
            return .summer
        default:
            return .autumn
        }
    }
}
