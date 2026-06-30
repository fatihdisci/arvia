import SwiftUI
import SwiftData

// MARK: - Garaj (Garage) Tab
// Kullanıcının araçlarını gösteren ana ekran.
// Premium araç dijital dosyası hissi: Ana araç hero kartı, hızlı işlemler,
// dosya tamlığı ve ikincil araçlar sakin bir hiyerarşide sunulur.

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var paywallService: PaywallService
    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<Reminder> { $0.statusRaw != "completed" },
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
    @State private var activeVehicleIndex = 0
    @State private var navigationPath: [UUID] = []
    @State private var hasAppeared = false

    private var activeVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt == nil }
    }

    private var archivedVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt != nil }
    }

    private var currentVehicle: Vehicle? {
        guard !activeVehicles.isEmpty, activeVehicleIndex < activeVehicles.count else {
            return nil
        }
        return activeVehicles[activeVehicleIndex]
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
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Ayarlar")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleAddVehicle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .accessibilityLabel("Araç Ekle")
                }

                if !archivedVehicles.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showArchivedVehicles.toggle()
                        } label: {
                            Image(systemName: "archivebox")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .accessibilityLabel("Arşivlenmiş Araçlar")
                    }
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
            .sheet(isPresented: $showAddMTVReminder) {
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

    // MARK: - Main Garage Content
    private var garageContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 1. Hero Vehicle Card(s)
                if activeVehicles.count > 1 {
                    TabView(selection: $activeVehicleIndex) {
                        ForEach(Array(activeVehicles.enumerated()), id: \.offset) { index, vehicle in
                            NavigationLink {
                                VehicleDetailView(vehicle: vehicle)
                            } label: {
                                heroCardContent(vehicle: vehicle)
                            }
                            .buttonStyle(PlainCardButtonStyle())
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 392)
                    .padding(.horizontal, AppSpacing.screenMarginH)

                    // Subtle page indicator
                    HStack(spacing: 6) {
                        ForEach(0..<activeVehicles.count, id: \.self) { i in
                            Circle()
                                .fill(i == activeVehicleIndex ? AppColors.accentPrimary : AppColors.border)
                                .frame(width: 6, height: 6)
                        }
                    }
                } else if let vehicle = activeVehicles.first {
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

                // 3. Quick Actions — Hızlı İşlemler
                if let vehicle = currentVehicle {
                    quickActionsSection(vehicle: vehicle)
                }

                // 4. Lightweight garage summary
                garageSummaryStrip

                // 5. Archived vehicles
                if !archivedVehicles.isEmpty {
                    archivedSection
                }

                Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
            }
            .padding(.vertical, AppSpacing.md)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .animation(.easeOut(duration: 0.35), value: hasAppeared)
        }
        .onAppear { hasAppeared = true }
        .onChange(of: activeVehicles.count) { _, newCount in
            guard newCount > 0 else { return }
            if activeVehicleIndex >= newCount {
                activeVehicleIndex = newCount - 1
            }
        }
    }

    // MARK: - Hero Card Content
    /// Sadece kart içeriği; NavigationLink ve padding ayrı ayrı sarılır
    /// (tek araçta doğrudan, çoklu araçta TabView içinde).
    private func heroCardContent(vehicle: Vehicle) -> some View {
        heroCardInner(vehicle: vehicle)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                    .fill(Color.appSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                    .stroke(AppColors.border.opacity(0.6), lineWidth: 0.5)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\\(vehicle.plate), \\(vehicle.fullName), \\(vehicle.odometerDisplay)")
    }

    private func heroCardInner(vehicle: Vehicle) -> some View {
        VStack(spacing: 0) {
            heroImageArea(vehicle: vehicle)
            heroMetadataArea(vehicle: vehicle)
        }
    }

    private func heroImageArea(vehicle: Vehicle) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let photoFileName = vehicle.photoFileName,
               let image = VehiclePhotoStorageService.shared.loadPhoto(fileName: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 190)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        AppColors.vehicle.opacity(0.96),
                        AppColors.accentPrimary.opacity(0.78),
                        AppColors.backgroundSecondary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: vehicle.vehicleType.heroSymbol)
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.42))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.12),
                    .black.opacity(0.2),
                    .black.opacity(0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(vehicle.nickname.isEmpty ? "Seçili araç" : vehicle.nickname)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 2)

                Text(vehicle.fullName.isEmpty ? "Araç dosyası" : vehicle.fullName)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 2)
            }
            .padding(AppSpacing.md)
        }
        .frame(height: 190)
    }

    private func heroMetadataArea(vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(vehicle.plate.isEmpty ? "Plaka yok" : vehicle.plate)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    if let year = vehicle.year {
                        Text("\(year) · \(vehicle.vehicleType.displayName)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                statusPill(for: vehicle)
            }

            HStack(spacing: AppSpacing.xs) {
                infoBadge(icon: "gauge.with.needle", text: vehicle.odometerDisplay)
                infoBadge(icon: "fuelpump", text: vehicle.fuelType.displayName)
                if let trans = vehicle.transmissionType {
                    infoBadge(
                        icon: trans == .automatic ? "a.circle" : "m.circle",
                        text: trans.displayName
                    )
                }
            }

            if let reminder = upcomingReminder(for: vehicle) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: reminder.isOverdue ? "exclamationmark.triangle.fill" : "bell.badge")
                        .font(.caption)
                        .foregroundColor(reminder.isOverdue ? AppColors.critical : AppColors.warning)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(reminder.isOverdue ? "Öncelik istiyor" : "Sıradaki önemli iş")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Text(reminder.title.isEmpty ? reminder.type.displayName : reminder.title)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill((reminder.isOverdue ? AppColors.critical : AppColors.warning).opacity(0.075))
                )
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusPill(for vehicle: Vehicle) -> some View {
        let score = computeFileScore(for: vehicle)
        return Label("%\(score)", systemImage: score >= 80 ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
            .font(AppTypography.captionMedium)
            .foregroundColor(score >= 80 ? AppColors.success : AppColors.accentPrimary)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill((score >= 80 ? AppColors.success : AppColors.accentPrimary).opacity(0.085))
            )
            .overlay(
                Capsule()
                    .stroke((score >= 80 ? AppColors.success : AppColors.accentPrimary).opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityLabel("Dosya tamlığı yüzde \(score)")
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

    // MARK: - Quick Action Rail
    private var quickActionRail: some View {
        QuickActionRail(actions: [
            .init(icon: "gauge.with.needle", label: "Km", color: AppColors.vehicle) {
                showQuickKmUpdate = true
            },
            .init(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {
                showAddExpense = true
            },
            .init(icon: "fuelpump", label: "Yakıt", color: AppColors.warning) {
                showAddFuelExpense = true
            },
            .init(icon: "doc.text.viewfinder", label: "Belge", color: AppColors.document) {
                showAddDocument = true
            },
            .init(icon: "bell.badge", label: "Hatırlatıcı", color: AppColors.success) {
                showAddReminder = true
            },
        ])
    }

    private func quickActionsSection(vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hızlı İşlemler")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text(vehicle.plate.isEmpty ? "Seçili araç" : vehicle.plate)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenMarginH)

            quickActionRail
        }
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColors.backgroundSecondary.opacity(0.68))
        )
        .padding(.horizontal, AppSpacing.screenMarginH)
        .accessibilityElement(children: .contain)
    }

    private var garageSummaryStrip: some View {
        HStack(spacing: AppSpacing.sm) {
            miniSummary(icon: "car.2", title: "\(activeVehicles.count)", subtitle: "aktif araç")
            miniSummary(icon: "bell.badge", title: "\(activeReminders.filter { reminder in activeVehicles.contains { $0.id == reminder.vehicleId } }.count)", subtitle: "açık iş")
            miniSummary(icon: "archivebox", title: "\(archivedVehicles.count)", subtitle: "arşiv")
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func miniSummary(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(AppColors.accentPrimary.opacity(0.09)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(Color.appSurface)
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
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Bugün Garajında")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Aracınla ilgili bugün dikkat etmen gerekenler.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)

            if let primary = insights.first {
                VStack(spacing: AppSpacing.sm) {
                    ContextualInsightCompactCard(insight: primary, prominence: .primary) {
                        handleContextAction(primary.action)
                    }

                    ForEach(insights.dropFirst().prefix(2)) { insight in
                        ContextualInsightCompactCard(insight: insight, prominence: .secondary) {
                            handleContextAction(insight.action)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
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
        if let index = activeVehicles.firstIndex(where: { $0.id == vehicleId }) {
            activeVehicleIndex = index
        }
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
        if !vehicle.brand.isEmpty { score += 10 }
        if !vehicle.model.isEmpty { score += 10 }
        if vehicle.year != nil { score += 10 }
        if vehicle.currentOdometer > 0 { score += 10 }
        if vehicle.transmissionType != nil { score += 10 }
        if vehicle.purchaseDate != nil { score += 10 }
        if vehicle.purchasePrice != nil { score += 10 }
        // Motosiklet özel: motor hacmi varsa bonus
        if vehicle.vehicleType == .motorcycle, vehicle.engineCC != nil { score += 10 }
        let vehReminders = activeReminders.filter { $0.vehicleId == vehicle.id }
        if !vehReminders.isEmpty { score += 15 }
        if !vehReminders.contains(where: { $0.isOverdue }) { score += 15 }
        if !recentExpenses(for: vehicle).isEmpty { score += 5 }
        if !recentServices(for: vehicle).isEmpty { score += 5 }
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

// MARK: - Plain Card Button Style
// Kart şeklindeki butonlarda varsayılan buton animasyonu yerine
// hafif opacity değişimi kullanır.
struct PlainCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
@MainActor
private func emptyPreviewContainer() -> ModelContainer {
    let schema = Schema([Vehicle.self, Reminder.self, Expense.self,
                         ServiceRecord.self, PartChange.self,
                         VehicleDocument.self, InspectionReport.self,
                         SaleFile.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: config)
}

#Preview("Garaj — Boş") {
    GarageView()
        .modelContainer(emptyPreviewContainer())
}

#Preview("Garaj — Araçlar") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Garaj — Dark Mode") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
        .preferredColorScheme(.dark)
}
