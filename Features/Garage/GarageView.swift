import SwiftUI
import SwiftData

// MARK: - Garaj (Garage) Tab
// Kullanıcının araçlarını gösteren ana ekran.
// Premium araç dijital dosyası hissi: Ana araç hero kartı, hızlı işlemler,
// Dosya Skoru ve ikincil araçlar sakin bir hiyerarşide sunulur.

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var paywallService: PaywallService
    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<Reminder> { $0.statusRaw != "Tamamlandı" },
           sort: \Reminder.dueDate)
    private var activeReminders: [Reminder]
    @Query private var allExpenses: [Expense]
    @Query private var allServiceRecords: [ServiceRecord]
    @Query(sort: \VehicleDocument.createdAt, order: .reverse) private var allDocuments: [VehicleDocument]
    @Query private var allInspectionReports: [InspectionReport]

    @State private var showAddVehicle = false
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showArchivedVehicles = false

    // QuickAction sheets
    @State private var showAddExpense = false
    @State private var showAddService = false
    @State private var showAddDocument = false
    @State private var showAddReminder = false
    @State private var showAddMTVReminder = false
    @State private var showAddFuelExpense = false
    @State private var showQuickKmUpdate = false
    @State private var showSaleFile = false
    @State private var paywallFeature: PaywallView.PaywallFeature = .secondVehicle
    @State private var activeVehicleId: UUID?
    @State private var navigationPath: [UUID] = []
    @State private var hasAppeared = false

    private var activeVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt == nil }
    }

    private var archivedVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt != nil }
    }

    private var activeVehicleIndex: Int {
        guard let id = activeVehicleId else { return 0 }
        return activeVehicles.firstIndex(where: { $0.id == id }) ?? 0
    }

    private var currentVehicle: Vehicle? {
        if let id = activeVehicleId, let vehicle = activeVehicles.first(where: { $0.id == id }) {
            return vehicle
        }
        return activeVehicles.first
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if vehicles.isEmpty {
                    emptyGarage
                } else if activeVehicles.isEmpty {
                    onlyArchivedView
                } else {
                    garageContent
                }
            }
            .navigationTitle("Garaj")
            .toolbarTitleDisplayMode(.inlineLarge)
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleAddVehicle()
                    } label: {
                        Label("Araç Ekle", systemImage: "plus")
                            .font(AppTypography.bodySecondary)
                            .foregroundColor(AppColors.textOnAccent)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppColors.accentPrimary)
                            )
                    }
                    .accessibilityLabel("Araç Ekle")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Ayarlar", systemImage: "gearshape")
                        }

                        if !archivedVehicles.isEmpty {
                            Button {
                                showArchivedVehicles.toggle()
                            } label: {
                                Label("Arşivlenmiş Araçlar", systemImage: "archivebox")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Diğer")
                }
            }
            .sheet(isPresented: $showAddVehicle) {
                VehicleFormView()
            }
            .sheet(isPresented: $showAddExpense) {
                ExpenseFormView(preselectedVehicleId: currentVehicle?.id)
            }
            .sheet(isPresented: $showAddFuelExpense) {
                ExpenseFormView(preselectedVehicleId: currentVehicle?.id, preselectedCategory: .fuel)
            }
            .sheet(isPresented: $showAddService) {
                ServiceRecordFormView(preselectedVehicleId: currentVehicle?.id)
            }
            .sheet(isPresented: $showAddDocument) {
                DocumentFormView(preselectedVehicleId: currentVehicle?.id)
            }
            .sheet(isPresented: $showAddReminder) {
                ReminderFormView(preselectedVehicleId: currentVehicle?.id)
            }
            .sheet(isPresented: $showAddMTVReminder, onDismiss: {
                if let vehicle = currentVehicle {
                    let month = Calendar.current.component(.month, from: Date())
                    let expectedType: ReminderType = (month == 1) ? .mtvFirst : .mtvSecond
                    let hasActiveMTV = activeReminders.contains { reminder in
                        reminder.vehicleId == vehicle.id && reminder.type == expectedType
                    }
                    if hasActiveMTV {
                        InsightSnoozeStore().clearReminderSnoozes(
                            for: vehicle.id,
                            types: [.calendarPeriod]
                        )
                    }
                }
            }) {
                ReminderFormView(
                    preselectedVehicleId: currentVehicle?.id,
                    preselectedTemplate: Calendar.current.component(.month, from: Date()) == 7 ? .mtvSecond : .mtvFirst
                )
            }
            .sheet(isPresented: $showQuickKmUpdate) {
                if let vehicle = currentVehicle {
                    QuickOdometerUpdateSheet(vehicle: vehicle)
                }
            }
            .sheet(isPresented: $showSaleFile) {
                if let vehicle = currentVehicle {
                    SaleFileView(vehicle: vehicle)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: paywallFeature)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: UUID.self) { vehicleId in
                if let vehicle = vehicles.first(where: { $0.id == vehicleId }) {
                    VehicleDetailView(vehicle: vehicle)
                } else {
                    EmptyStateView(
                        icon: "car",
                        title: "Araç bulunamadı",
                        description: "Bildirimdeki araç silinmiş veya arşivlenmiş olabilir.",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            .onChange(of: navigationRouter.pendingNotificationRoute) { _, route in
                handleNotificationRoute(route)
            }
            .onAppear {
                handleNotificationRoute(navigationRouter.pendingNotificationRoute)
            }
        }
    }

    // MARK: - Empty State
    private var emptyGarage: some View {
        EmptyStateView(
            icon: "car",
            title: "İlk aracının dosyasını oluşturalım",
            description: "Muayene, sigorta, bakım ve belgeleri tek yerde takip etmek için aracını ekle.",
            actionTitle: "Araç Ekle",
            action: { handleAddVehicle() }
        )
    }

    // MARK: - Only Archived
    private var onlyArchivedView: some View {
        VStack(spacing: AppSpacing.lg) {
            EmptyStateView(
                icon: "archivebox",
                title: "Tüm araçlar arşivlenmiş",
                description: "Yeni bir araç ekleyebilir veya arşivlenmiş araçları görüntüleyebilirsin.",
                actionTitle: "Araç Ekle",
                action: { handleAddVehicle() }
            )

            if !archivedVehicles.isEmpty {
                archivedSection
            }
        }
    }

    // MARK: - Vehicle Picker
    /// Çoklu araç varken aktif aracı değiştirmek için chevron pagination.
    /// Apple Music playlist header gibi — kaç araç olursa olsun sıkışmaz,
    /// çünkü ortadaki label değişir, kenar butonlar sabit kalır.
    private var vehiclePicker: some View {
        HStack(spacing: AppSpacing.md) {
            chevronButton(systemName: "chevron.left", enabled: canGoPrevious) {
                goToPreviousVehicle()
            }

            VStack(spacing: 2) {
                Text(currentVehicle.flatMap { vehiclePickerLabel(for: $0) } ?? "Araç")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(activeVehicleIndex + 1) / \(activeVehicles.count)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                // Ortadaki etikete tıklayınca hafif haptic ile küçük bir geri bildirim
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }

            chevronButton(systemName: "chevron.right", enabled: canGoNext) {
                goToNextVehicle()
            }
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    private func chevronButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(enabled
                              ? AppColors.backgroundSecondary
                              : AppColors.backgroundSecondary.opacity(0.4))
                )
                .foregroundColor(enabled ? AppColors.textPrimary : AppColors.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var canGoPrevious: Bool {
        activeVehicleIndex > 0
    }

    private var canGoNext: Bool {
        activeVehicleIndex < activeVehicles.count - 1
    }

    private func goToPreviousVehicle() {
        guard canGoPrevious else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        activeVehicleId = activeVehicles[activeVehicleIndex - 1].id
    }

    private func goToNextVehicle() {
        guard canGoNext else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        activeVehicleId = activeVehicles[activeVehicleIndex + 1].id
    }

    private func vehiclePickerLabel(for vehicle: Vehicle) -> String {
        if !vehicle.plate.isEmpty { return vehicle.plate }
        if !vehicle.fullName.isEmpty { return vehicle.fullName }
        if let idx = activeVehicles.firstIndex(where: { $0.id == vehicle.id }) {
            return "Araç \(idx + 1)"
        }
        return "Araç"
    }

    // MARK: - Main Garage Content
    private var garageContent: some View {
        VStack(spacing: 0) {
            // 0. Çoklu araç picker — ScrollView DIŞINDA, sabit
            // NavigationLink + ScrollView'in gesture'ı chevron tıklamasını
            // yiyordu. Sabit alanda bağımsız Button olarak çalışıyor.
            if activeVehicles.count > 1 {
                vehiclePicker
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
            }

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 1. Hero Vehicle Card — tek, currentVehicle'a göre
                    if let vehicle = currentVehicle {
                        NavigationLink {
                            VehicleDetailView(vehicle: vehicle)
                        } label: {
                            heroCardContent(vehicle: vehicle)
                        }
                        .buttonStyle(PlainCardButtonStyle())
                        .padding(.horizontal, AppSpacing.screenMarginH)
                    }

                    // 2. Bugün Garajında
                    if let vehicle = currentVehicle {
                        todayGarageSection(vehicle: vehicle)
                    }

                    // 2.5. Dosyani Tamamla Checklist — sadece eksik kriter varsa
                    if let vehicle = currentVehicle {
                        dosyaniTamamlaSection(vehicle: vehicle)
                    }

                    // 3. Lightweight garage summary
                    garageSummaryStrip

                    // 5. Archived vehicles
                    if !archivedVehicles.isEmpty {
                        archivedSection
                    }

                    Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
                }
                .padding(.bottom, AppSpacing.md)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35), value: hasAppeared)
            }
        }
        .onAppear { hasAppeared = true }
        .onChange(of: activeVehicles.count) { _, newCount in
            guard newCount > 0 else { return }
            if let id = activeVehicleId, !activeVehicles.contains(where: { $0.id == id }) {
                activeVehicleId = activeVehicles.first?.id
            }
        }
    }

    // MARK: - Hero Card Content
    /// İki ayrı card: fotoğraf (üstte) + bilgi card'ı (altta).
    /// NavigationLink ve screen margin ayrı ayrı sarılır.
    private func heroCardContent(vehicle: Vehicle) -> some View {
        VStack(spacing: AppSpacing.md) {
            heroImageArea(vehicle: vehicle)
            heroMetadataCard(vehicle: vehicle)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(vehicle.plate), \(vehicle.fullName), \(vehicle.odometerDisplay)")
    }

    private func heroImageArea(vehicle: Vehicle) -> some View {
        ZStack {
            if let photoFileName = vehicle.photoFileName,
               let image = VehiclePhotoStorageService.shared.loadPhoto(fileName: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        AppColors.vehicle.opacity(0.92),
                        AppColors.vehicle.opacity(0.7),
                        AppColors.accentPrimary.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: vehicle.vehicleType.heroSymbol)
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.32))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            // Tıklanabilirlik affordance'i — kullanıcı hero'nun
            // NavigationLink olduğunu görsün
            HStack(spacing: 4) {
                Text("Detay")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.55))
            )
            .padding(AppSpacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func heroMetadataCard(vehicle: Vehicle) -> some View {
        let score = computeFileScore(for: vehicle)

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Satır 1: kimlik (fullName + plaka yan yana)
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.fullName.isEmpty ? "Araç dosyası" : vehicle.fullName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if !vehicle.nickname.isEmpty {
                        Text(vehicle.nickname)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.accentPrimary)
                            .lineLimit(1)
                    }

                    if vehicle.year != nil {
                        HStack(spacing: 6) {
                            Text(String(vehicle.year!))
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                            Text("•")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                            Text(vehicle.vehicleType.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: AppSpacing.sm)

                // Plaka pill — sağ üstte
                Text(vehicle.plate.isEmpty ? "—" : vehicle.plate)
                    .font(.custom("JetBrainsMono-SemiBold", size: 14))
                    .tracking(1.5)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundSecondary)
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppColors.border, lineWidth: 0.5)
                    )
                    .frame(maxWidth: 130, alignment: .trailing)
            }

            Divider()

            // Satır 2: metrics (km, yakıt, vites) — düz satır
            HStack(spacing: AppSpacing.xs) {
                metricPill(icon: "gauge.with.needle", text: vehicle.odometerDisplay)
                metricPill(icon: "fuelpump", text: vehicle.fuelType.displayName)
                if let trans = vehicle.transmissionType {
                    metricPill(
                        icon: trans == .automatic ? "a.circle" : "m.circle",
                        text: trans.displayName
                    )
                }
                Spacer(minLength: 0)
            }

            // Satır 3a: Dosya Skoru — tam genişlik tek satır
            compactFileBadge(score: score)

            // Satır 3b: sıradaki önemli iş — ayrı iki satır (başlık + reminder adı)
            if let reminder = upcomingReminder(for: vehicle) {
                heroReminderRow(reminder)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func metricPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(AppTypography.captionMedium)
                .lineLimit(1)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs + 2)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(AppColors.backgroundSecondary.opacity(0.7))
        )
    }

    private func heroIdentityBlock(vehicle: Vehicle) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Text(vehicle.plate.isEmpty ? "Plaka yok" : vehicle.plate)
                .font(.custom("JetBrainsMono-Bold", size: 17))
                .tracking(1.5)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundSecondary.opacity(0.86))
                )

            if let year = vehicle.year {
                HStack(spacing: AppSpacing.xxs) {
                    Text(String(year))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("•")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text(vehicle.vehicleType.displayName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private func heroReminderRow(_ reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: reminder.isOverdue ? "exclamationmark.triangle.fill" : "bell.badge")
                    .font(.caption2)
                    .foregroundColor(reminder.isOverdue ? AppColors.critical : AppColors.warning)
                Text(reminder.isOverdue ? "Öncelik istiyor" : "Sıradaki önemli iş")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                Spacer(minLength: 0)
            }
            Text(reminder.title.isEmpty ? reminder.type.displayName : reminder.title)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func compactFileBadge(score: Int) -> some View {
        let barColor = score >= 80 ? AppColors.success : AppColors.accentPrimary
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundColor(barColor)
                Text("Dosya Skoru")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                Spacer(minLength: 0)
                Text("%\(score)")
                    .font(AppTypography.labelMono)
                    .foregroundColor(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(6, geo.size.width * CGFloat(score) / 100.0), height: 6)
                        .animation(.easeOut(duration: 0.7), value: score)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(barColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .stroke(barColor.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityLabel("Dosya skoru yüzde \(score)")
    }

    private func infoBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(AppTypography.captionMedium)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AppColors.backgroundSecondary.opacity(0.82))
        )
    }

    private var garageSummaryStrip: some View {
        let activeReminderCount = activeReminders.filter { r in activeVehicles.contains { $0.id == r.vehicleId } }.count
        let thisMonth = Calendar.current.component(.month, from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        let thisMonthExpenses = allExpenses.filter {
            let comps = Calendar.current.dateComponents([.month, .year], from: $0.date)
            return comps.month == thisMonth && comps.year == thisYear
        }
        let monthlyTotal = thisMonthExpenses.reduce(0) { $0 + $1.amount }

        let upcomingReminder = activeReminders
            .filter { r in activeVehicles.contains { $0.id == r.vehicleId } && r.dueDate != nil }
            .min(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                miniSummary(
                    icon: "car.2",
                    value: "\(activeVehicles.count)",
                    label: "Aktif Araç",
                    color: AppColors.accentPrimary
                )
                miniSummary(
                    icon: "bell.badge",
                    value: "\(activeReminderCount)",
                    label: "Açık İş",
                    color: activeReminderCount > 3 ? AppColors.warning : AppColors.success
                )
                miniSummary(
                    icon: "turkishlirasign.circle",
                    value: monthlyTotal > 0 ? formatCurrency(monthlyTotal) : "—",
                    label: "Bu Ay",
                    color: AppColors.accentSecondary
                )
                if let next = upcomingReminder, let nextDue = next.dueDate {
                    miniSummary(
                        icon: "calendar.badge.clock",
                        value: nextDue.formatted(.dateTime.day().month(.abbreviated)),
                        label: next.type.displayName,
                        color: next.isOverdue ? AppColors.critical : AppColors.accentPrimary
                    )
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₺0"
    }

    private func miniSummary(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(height: 20)
            Text(value)
                .font(.custom("JetBrainsMono-SemiBold", size: 15))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.backgroundSecondary.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func todayGarageSection(vehicle: Vehicle) -> some View {
        let insights = VehicleInsightService.shared.garageSummary(
            for: vehicle,
            reminders: activeReminders.filter { $0.vehicleId == vehicle.id },
            expenses: expenses(for: vehicle),
            serviceRecords: services(for: vehicle),
            documents: documents(for: vehicle),
            inspectionReports: inspectionReports(for: vehicle)
        )
        .filter { !InsightSnoozeStore().isSnoozed(vehicleId: vehicle.id, insightId: $0.id) }

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Bugün Garajında")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Öncelikli işlerini sakin bir sırayla takip et.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.accentPrimary.opacity(0.08)))
            }
            .padding(.horizontal, AppSpacing.screenMarginH)

            if let primary = insights.first {
                VStack(spacing: AppSpacing.sm) {
                    GarageDailyInsightCard(insight: primary, prominence: .primary) {
                        handleContextAction(primary.action)
                    }

                    ForEach(insights.dropFirst().prefix(1)) { insight in
                        GarageDailyInsightCard(insight: insight, prominence: .secondary) {
                            handleContextAction(insight.action)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
        }
    }

    // MARK: - Dosyani Tamamla Checklist
    /// Garaj hero altında gösterilen interaktif rehber kartı.
    /// 5 kriterden <5 tamamlandıysa gösterir, hepsi tamamlandıysa gizler.
    /// Mevcut `DosyaniTamamlaChecklist` component'ini yeniden kullanır (Karar 3.1).
    @ViewBuilder
    private func dosyaniTamamlaSection(vehicle: Vehicle) -> some View {
        if checklistDoneCount(vehicle) < 5 {
            DosyaniTamamlaChecklist(
                vehicle: vehicle,
                hasInspectionReminder: hasReminderType(vehicle, .inspection),
                hasInsuranceReminder: hasReminderType(vehicle, .trafficInsurance) || hasReminderType(vehicle, .casco),
                hasAnyExpenseOrService: !recentExpenses(for: vehicle).isEmpty || !recentServices(for: vehicle).isEmpty,
                hasAnyDocument: !recentDocuments(for: vehicle).isEmpty
            )
        }
    }

    // MARK: - Recent Activity
    private func recentActivitySection(vehicle: Vehicle) -> some View {
        let recentItems = recentRecords(for: vehicle)
        if recentItems.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Son İşlemler")

                VStack(spacing: 0) {
                    ForEach(Array(recentItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: item.icon)
                                .font(.subheadline)
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
                        .padding(.vertical, AppSpacing.sm)

                        if index < min(recentItems.count, 3) - 1 {
                            Divider()
                                .padding(.leading, 44)
                                .padding(.trailing, AppSpacing.screenMarginH)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .subtleShadow()
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
        )
    }

    // MARK: - Archived Section
    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            DisclosureGroup(isExpanded: $showArchivedVehicles) {
                ForEach(archivedVehicles) { vehicle in
                    NavigationLink {
                        VehicleDetailView(vehicle: vehicle)
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(AppColors.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Arşivlendi: \(vehicle.archivedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "archivebox")
                        .foregroundColor(AppColors.textTertiary)
                    Text("Arşivlenmiş Araçlar")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text("(\(archivedVehicles.count))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
    }

    // MARK: - Actions
    private func handleNotificationRoute(_ route: AppNotificationRoute?) {
        guard case let .vehicle(vehicleId, _)? = route else { return }
        activeVehicleId = vehicleId
        if navigationPath.last != vehicleId {
            navigationPath = [vehicleId]
        }
    }

    private func handleAddVehicle() {
        if paywallService.canAddVehicle(currentCount: activeVehicles.count) {
            showAddVehicle = true
        } else {
            paywallFeature = .secondVehicle
            showPaywall = true
        }
    }

    // MARK: - Helpers
    private func upcomingReminder(for vehicle: Vehicle) -> Reminder? {
        let reminders = activeReminders.filter { $0.vehicleId == vehicle.id }
        if let overdue = reminders.first(where: { $0.isOverdue }) { return overdue }
        if let today = reminders.first(where: { $0.isToday }) { return today }
        return reminders
            .filter { $0.dueDate != nil && !$0.isOverdue }
            .min(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
    }

    private func computeFileScore(for vehicle: Vehicle) -> Int {
        var score = 0

        // Temel bilgiler (40 puan) — plaka, kimlik, yakıt, satın alma
        if !vehicle.plate.isEmpty { score += 5 }
        if !vehicle.brand.isEmpty { score += 5 }
        if !vehicle.model.isEmpty { score += 5 }
        if vehicle.year != nil { score += 5 }
        if vehicle.currentOdometer > 0 { score += 5 }
        if vehicle.transmissionType != nil { score += 5 }
        if vehicle.vehicleType == .motorcycle, vehicle.engineCC != nil { score += 5 }
        if vehicle.purchaseDate != nil { score += 5 }

        // Araç fotoğrafı (10 puan)
        if vehicle.photoFileName != nil { score += 10 }

        // Belgeler (25 puan) — Dosya Skoru'nun en kritik parçası.
        // Belge olmadan Dosya Skoru %100 olamaz.
        let docs = documents(for: vehicle)
        if !docs.isEmpty { score += 15 }
        let uniqueDocTypes = Set(docs.map { $0.type })
        if uniqueDocTypes.count >= 3 { score += 10 }

        // Hatırlatıcı (10 puan)
        let vehReminders = activeReminders.filter { $0.vehicleId == vehicle.id }
        if !vehReminders.isEmpty { score += 10 }

        // Masraf + bakım (15 puan)
        if !expenses(for: vehicle).isEmpty { score += 8 }
        if !services(for: vehicle).isEmpty { score += 7 }

        return min(score, 100)
    }

    private func recentExpenses(for vehicle: Vehicle) -> [Expense] {
        expenses(for: vehicle)
    }

    private func recentServices(for vehicle: Vehicle) -> [ServiceRecord] {
        services(for: vehicle)
    }

    private func recentDocuments(for vehicle: Vehicle) -> [VehicleDocument] {
        documents(for: vehicle)
    }

    private func expenses(for vehicle: Vehicle) -> [Expense] {
        allExpenses.filter { $0.vehicleId == vehicle.id }
    }

    private func services(for vehicle: Vehicle) -> [ServiceRecord] {
        allServiceRecords.filter { $0.vehicleId == vehicle.id }
    }

    private func documents(for vehicle: Vehicle) -> [VehicleDocument] {
        allDocuments.filter { $0.vehicleId == vehicle.id }
    }

    private func inspectionReports(for vehicle: Vehicle) -> [InspectionReport] {
        allInspectionReports.filter { $0.vehicleId == vehicle.id }
    }

    private func handleContextAction(_ action: VehicleInsightAction) {
        switch action {
        case .updateOdometer:
            showQuickKmUpdate = true
        case .addExpense:
            showAddExpense = true
        case .addFuelExpense:
            showAddFuelExpense = true
        case .addDocument:
            showAddDocument = true
        case .addReminder:
            showAddReminder = true
        case .addMTVReminder:
            showAddMTVReminder = true
        case .addServiceRecord:
            showAddService = true
        case .openTodos:
            navigationRouter.selectedTab = .todos
        case .openSaleFile:
            showSaleFile = true
        case .addInspectionReport:
            showSaleFile = true
        }
    }

    private func hasReminderType(_ vehicle: Vehicle, _ type: ReminderType) -> Bool {
        activeReminders.contains { $0.vehicleId == vehicle.id && $0.type == type }
    }

    private func checklistDoneCount(_ vehicle: Vehicle) -> Int {
        var count = 0
        if !vehicle.brand.isEmpty && vehicle.currentOdometer > 0 { count += 1 }
        if hasReminderType(vehicle, .inspection) { count += 1 }
        if hasReminderType(vehicle, .trafficInsurance) || hasReminderType(vehicle, .casco) { count += 1 }
        if !recentExpenses(for: vehicle).isEmpty || !recentServices(for: vehicle).isEmpty { count += 1 }
        if !recentDocuments(for: vehicle).isEmpty { count += 1 }
        return count
    }

    private func criteriaMet(for vehicle: Vehicle) -> [String] {
        var met: [String] = []
        if !vehicle.brand.isEmpty { met.append("Marka") }
        if !vehicle.model.isEmpty { met.append("Model") }
        if vehicle.year != nil { met.append("Yıl") }
        if vehicle.currentOdometer > 0 { met.append("Km") }
        if vehicle.transmissionType != nil { met.append("Vites") }
        return met
    }

    private func criteriaMissing(for vehicle: Vehicle) -> [String] {
        var missing: [String] = []
        if vehicle.brand.isEmpty { missing.append("Marka") }
        if vehicle.model.isEmpty { missing.append("Model") }
        if vehicle.year == nil { missing.append("Yıl") }
        if vehicle.currentOdometer == 0 { missing.append("Km") }
        if vehicle.transmissionType == nil { missing.append("Vites") }
        return missing
    }

    private struct RecentRecordItem: Identifiable {
        let id: UUID
        let icon: String
        let title: String
        let subtitle: String
        let date: Date
    }

    private func recentRecords(for vehicle: Vehicle) -> [RecentRecordItem] {
        var items: [RecentRecordItem] = []
        for e in recentExpenses(for: vehicle) {
            items.append(RecentRecordItem(id: e.id, icon: e.category.defaultIcon, title: e.category.displayName, subtitle: e.amountCompactDisplay, date: e.date))
        }
        for s in recentServices(for: vehicle) {
            items.append(RecentRecordItem(id: s.id, icon: "wrench.and.screwdriver", title: s.serviceType.displayName, subtitle: s.vendorName ?? s.totalCostDisplay ?? "", date: s.date))
        }
        return items.sorted { $0.date > $1.date }
    }
}

// MARK: - Garage Daily Insight Card
private struct GarageDailyInsightCard: View {
    let insight: VehicleInsight
    var prominence: Prominence
    let action: () -> Void

    enum Prominence {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: prominence == .primary ? 18 : 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .fill(color.opacity(0.11))
                    )

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title)
                        .font(prominence == .primary ? AppTypography.cardTitle : AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.body)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(prominence == .primary ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 5) {
                        Text(insight.action.title)
                            .font(AppTypography.captionMedium)
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(color)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(prominence == .primary ? AppSpacing.md : AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(color.opacity(prominence == .primary ? 0.18 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body). \(insight.action.title)")
    }

    private var color: Color {
        switch insight.priority {
        case .important:
            return AppColors.critical
        case .warning:
            return AppColors.warning
        case .info:
            return AppColors.accentPrimary
        }
    }

    private var icon: String {
        switch insight.type {
        case .overdueReminder:
            return "exclamationmark.triangle.fill"
        case .upcomingReminder:
            return "bell.badge"
        case .calendarPeriod:
            return "calendar.badge.clock"
        case .odometerUpdate:
            return "gauge.with.needle"
        case .seasonalGuidance:
            return "sun.max"
        case .missingDocument:
            return "doc.text"
        case .monthlyExpensePrompt:
            return "turkishlirasign.circle"
        case .fuelTypeGuidance:
            return "fuelpump"
        case .transmissionGuidance:
            return "gearshape.2"
        case .odometerMilestone:
            return "flag.checkered"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .quietGoodState:
            return "checkmark.seal"
        case .saleFileReadiness:
            return "doc.richtext"
        }
    }
}

// MARK: - Plain Card Button Style
// Kart şeklindeki butonlarda varsayılan buton animasyonu yerine
// hafif opacity değişimi kullanır.
struct PlainCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("Garaj — Boş") {
    GarageView()
        .modelContainer(MockDataProvider.emptyPreviewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
}

#Preview("Garaj — Araçlar") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
}

#Preview("Garaj — Dark Mode") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
}

#Preview("Garaj — Dynamic Type") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
        .environment(\.dynamicTypeSize, .accessibility1)
}
