import SwiftUI
import SwiftData
import PhotosUI

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
    @Query private var allUsageProfiles: [VehicleUsageProfile]

    @AppStorage("assistant_profile_prompted") private var assistantProfilePrompted = false
    @State private var showAssistantProfile = false

    @State private var showAddVehicle = false
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showArchivedVehicles = false

    // Garaj hero card — fotoğraf yokken tıklayınca sistem fotoğraf seçici açılır
    // (önce fotoğraf eklensin, sonra detaya gidilsin).
    @State private var garagePhotoItem: PhotosPickerItem?

    // Faz 2.6 — Arvia Rehber tanıtım banner'ı snooze'u.
    // 0 = hiç dismiss edilmedi, aksi halde dismiss zamanı (epoch seconds).
    @AppStorage("guideIntroDismissedAt") private var guideIntroDismissedAt: Double = 0

    // QuickAction sheets
    @State private var showAddExpense = false
    @State private var showAddService = false
    @State private var showAddDocument = false
    @State private var showAddReminder = false
    @State private var showAddMTVReminder = false
    @State private var showAddFuelExpense = false
    @State private var insightDismissTrigger = false
    @State private var showQuickKmUpdate = false
    @State private var showSaleFile = false
    @State private var showReceiptScan = false
    @State private var showReceiptPaywall = false
    @State private var showMaintenancePlan = false
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
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Araç Ekle")
                                .font(AppTypography.captionMedium)
                        }
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 7)
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
                    .accessibilityLabel("Garaj Seçenekleri")
                }
            }
            .sheet(isPresented: $showAddVehicle) {
                VehicleWizardView()
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
            .sheet(isPresented: $showReceiptScan) {
                if let vehicle = currentVehicle {
                    ReceiptScanView(preselectedVehicleId: vehicle.id)
                }
            }
            .sheet(isPresented: $showReceiptPaywall) {
                PaywallView(feature: .receiptScan)
            }
            .sheet(isPresented: $showMaintenancePlan) {
                if let vehicle = currentVehicle {
                    MaintenancePlanView(vehicle: vehicle)
                }
            }
            .sheet(isPresented: $showAssistantProfile) {
                UsageProfileFlowView()
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
    /// Aktif araç plakasını üstte gösterir. Tek araçta sadece plaka label
    /// (chevron ve "1/1" yok), çoklu araçta chevron pagination + "N/M".
    private var vehiclePicker: some View {
        Group {
            if activeVehicles.count > 1 {
                multiVehiclePicker
            } else {
                singleVehicleLabel
            }
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    /// Tek araç — sadece plaka label, ortada hizalı.
    private var singleVehicleLabel: some View {
        Text(currentVehicle.flatMap { vehiclePickerLabel(for: $0) } ?? "Araç")
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    /// Çoklu araç — chevron pagination + plaka + "N/M" göstergesi.
    /// Apple Music playlist header gibi — kaç araç olursa olsun sıkışmaz,
    /// çünkü ortadaki label değişir, kenar butonlar sabit kalır.
    private var multiVehiclePicker: some View {
        HStack(spacing: AppSpacing.md) {
            chevronButton(systemName: "chevron.left", enabled: canGoPrevious, accessibilityLabel: "Önceki araç") {
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

            chevronButton(systemName: "chevron.right", enabled: canGoNext, accessibilityLabel: "Sonraki araç") {
                goToNextVehicle()
            }
        }
    }

    private func chevronButton(systemName: String, enabled: Bool, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
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
        .accessibilityLabel(accessibilityLabel)
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
            // 0. Araç plaka picker — ScrollView DIŞINDA, sabit
            // NavigationLink + ScrollView'in gesture'ı chevron tıklamasını
            // yiyordu. Sabit alanda bağımsız Button olarak çalışıyor.
            // Tek araçta chevron'lar disabled, plaka label ortada görünür.
            vehiclePicker
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 1. Hero Vehicle Card — tek, currentVehicle'a göre
                    // Fotoğraf varsa → tıklayınca VehicleDetail açılır.
                    // Fotoğraf yoksa → tıklayınca önce sistem fotoğraf seçici açılır.
                    if let vehicle = currentVehicle {
                        if vehicle.photoFileName != nil {
                            NavigationLink {
                                VehicleDetailView(vehicle: vehicle)
                            } label: {
                                heroCardContent(vehicle: vehicle)
                            }
                            .buttonStyle(PlainCardButtonStyle())
                            .padding(.horizontal, AppSpacing.screenMarginH)
                        } else {
                            heroPhotoPicker(for: vehicle)
                                .padding(.horizontal, AppSpacing.screenMarginH)
                        }
                    }

                    // 1.5. Dosya Skoru — tek metrik olarak (Karar 3.1)
                    // Hero altında, checklist üstünde. Circular progress + skor aralığına
                    // göre yumuşak/teşvik edici mesaj + eksik kriterler.
                    if let vehicle = currentVehicle {
                        DossierCompletenessCard(
                            score: computeFileScore(for: vehicle),
                            criteriaMissing: criteriaMissing(for: vehicle)
                        )
                        .padding(.horizontal, AppSpacing.screenMarginH)
                    }

                    // 1.6. Kişisel Bakım Planı teaser — Dosya Skoru altında
                    // Free: kilitli + paywall, Pro: işlevsel giriş
                    if let vehicle = currentVehicle {
                        maintenancePlanTeaser(vehicle: vehicle)
                            .padding(.horizontal, AppSpacing.screenMarginH)
                    }

                    // 2. Bugün Garajında
                    if let vehicle = currentVehicle {
                        let _ = insightDismissTrigger  // store değişince re-render
                        todayGarageSection(vehicle: vehicle)
                    }

                    // 2.0. Faz 2.6 — Yeni kullanıcı rehber tanıtım banner'ı.
                    // İlk araç eklendikten sonra bir kez gösterilir, 7 gün snooze.
                    if shouldShowRehberIntro {
                        RehberIntroBanner(onDismiss: dismissRehberIntro)
                            .padding(.horizontal, AppSpacing.screenMarginH)
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
        .overlay(alignment: .bottomTrailing) {
            FloatingQuickActionButton(
                onAddExpense: { showAddExpense = true },
                onScanReceipt: { handleGarageScanReceipt() },
                onAddReminder: { showAddReminder = true },
                showReceiptProBadge: !paywallService.canUseReceiptScan
            )
        }
        .onAppear { hasAppeared = true }
        .onChange(of: activeVehicles.count) { _, newCount in
            guard newCount > 0 else { return }
            if let id = activeVehicleId, !activeVehicles.contains(where: { $0.id == id }) {
                activeVehicleId = activeVehicles.first?.id
            }
        }
    }

    private func handleGarageScanReceipt() {
        if paywallService.canUseReceiptScan {
            showReceiptScan = true
        } else {
            paywallFeature = .receiptScan
            showReceiptPaywall = true
        }
    }

    // MARK: - Hero Card Content
    /// Fotoğrafsız hero — tıklayınca sistem fotoğraf seçici açılır.
    /// Kullanıcı önce fotoğraf ekler, sonra detaya gider.
    @ViewBuilder
    private func heroPhotoPicker(for vehicle: Vehicle) -> some View {
        PhotosPicker(selection: $garagePhotoItem, matching: .images) {
            heroCardContent(vehicle: vehicle)
        }
        .buttonStyle(PlainCardButtonStyle())
        .onChange(of: garagePhotoItem) { _, newItem in
            if let item = newItem { loadGaragePhoto(item, for: vehicle) }
        }
    }

    /// Garaj'dan seçilen fotoğrafı kaydet, vehicle'a bağla.
    private func loadGaragePhoto(_ item: PhotosPickerItem, for vehicle: Vehicle) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                guard let image = UIImage(data: data) else { return }
                let fileName = try VehiclePhotoStorageService.shared.savePhoto(image)
                await MainActor.run {
                    vehicle.photoFileName = fileName
                    try? modelContext.save()
                    garagePhotoItem = nil
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    garagePhotoItem = nil
                }
            }
        }
    }

    // MARK: - Hero Card Content
    /// Sadece araç fotoğrafı. Fotoğraf yoksa eklemeye teşvik eden placeholder.
    private func heroCardContent(vehicle: Vehicle) -> some View {
        ZStack {
            if let photoFileName = vehicle.photoFileName,
               let image = VehiclePhotoStorageService.shared.loadPhoto(fileName: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Fotoğraf eklemeye teşvik eden placeholder
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(AppColors.accentPrimary.opacity(0.55))
                    VStack(spacing: 4) {
                        Text("Aracının fotoğrafını ekle")
                            .font(AppTypography.bodySecondary)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Garajını kişiselleştirmek için dokun")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.backgroundSecondary,
                            AppColors.surfacePrimary,
                            AppColors.accentPrimary.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
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

    private var garageSummaryStrip: some View {
        let activeReminderCount = activeReminders.filter { r in activeVehicles.contains { $0.id == r.vehicleId } }.count
        let thisMonth = Calendar.current.component(.month, from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        let thisMonthExpenses = allExpenses.filter {
            let comps = Calendar.current.dateComponents([.month, .year], from: $0.date)
            return comps.month == thisMonth && comps.year == thisYear
        }
        let monthlyTotal = thisMonthExpenses.reduce(0) { $0 + $1.amount }

        return VStack(spacing: AppSpacing.xs) {
            summaryRow(icon: "car.2", value: "\(activeVehicles.count)", label: "aktif araç", color: AppColors.accentPrimary)
            summaryRow(icon: "bell.badge", value: "\(activeReminderCount)", label: "açık iş", color: activeReminderCount > 0 ? AppColors.warning : AppColors.success)
            summaryRow(icon: "turkishlirasign.circle", value: monthlyTotal > 0 ? formatCurrency(monthlyTotal) : "—", label: "bu ay", color: AppColors.accentSecondary)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func summaryRow(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(AppTypography.bodySecondary)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.custom("JetBrainsMono-SemiBold", size: 15))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.backgroundSecondary.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₺0"
    }

    private func todayGarageSection(vehicle: Vehicle) -> some View {
        let insights = VehicleInsightService.shared.garageSummary(
            for: vehicle,
            reminders: activeReminders.filter { $0.vehicleId == vehicle.id },
            expenses: expenses(for: vehicle),
            serviceRecords: services(for: vehicle),
            documents: documents(for: vehicle),
            inspectionReports: inspectionReports(for: vehicle),
            assistant: assistantInputs(for: vehicle)
        )
        .filter { !InsightSnoozeStore.shared.isDismissed(insightType: $0.type, forVehicle: vehicle.id) }
        .filter { !InsightSnoozeStore.shared.isSnoozed(insightType: $0.type, forVehicle: vehicle.id) }
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
            }
            .padding(.horizontal, AppSpacing.screenMarginH)

            if let primary = insights.first {
                VStack(spacing: AppSpacing.sm) {
                    VehicleInsightCard(
                        insight: primary,
                        vehicleId: vehicle.id,
                        onAction: { handleContextAction($0) },
                        onDismiss: { snoozeInsight(insight: primary, vehicleId: vehicle.id) }
                    )

                    ForEach(insights.dropFirst().prefix(1)) { insight in
                        VehicleInsightCard(
                            insight: insight,
                            vehicleId: vehicle.id,
                            onAction: { handleContextAction($0) },
                            onDismiss: { snoozeInsight(insight: insight, vehicleId: vehicle.id) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenMarginH)
            } else {
                // Tüm öneriler kapatıldı — sakin boş state
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.body)
                        .foregroundColor(AppColors.success.opacity(0.6))
                    Text("Tüm önerileri inceledin.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
                .padding(AppSpacing.md)
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
        }
    }

    // MARK: - Dosyani Tamamla Checklist
    /// Garaj hero altında gösterilen interaktif rehber kartı.
    /// 6 kriterden hepsi tamamlandıysa gizler (bakım planı dahil).
    /// Mevcut `DosyaniTamamlaChecklist` component'ini yeniden kullanır (Karar 3.1).
    @ViewBuilder
    private func dosyaniTamamlaSection(vehicle: Vehicle) -> some View {
        let hasPlan = paywallService.isPro && MaintenancePlanCacheStore.load(vehicleId: vehicle.id) != nil
        // Temel 5 kriter tamamlandıysa ama bakım planı yoksa hâlâ göster (Pro nudge).
        if checklistDoneCount(vehicle) < 5 || (paywallService.isPro && !hasPlan) {
            DosyaniTamamlaChecklist(
            vehicle: vehicle,
            hasInspectionReminder: hasReminderType(vehicle, .inspection),
            hasInsuranceReminder: hasReminderType(vehicle, .trafficInsurance) || hasReminderType(vehicle, .casco),
            hasAnyExpenseOrService: !recentExpenses(for: vehicle).isEmpty || !recentServices(for: vehicle).isEmpty,
            hasAnyDocument: !recentDocuments(for: vehicle).isEmpty,
            hasMaintenancePlan: paywallService.isPro && MaintenancePlanCacheStore.load(vehicleId: vehicle.id) != nil,
            onMaintenancePlan: {
                if paywallService.canUseAssistant {
                    showMaintenancePlan = true
                } else {
                    paywallFeature = .assistant
                    showPaywall = true
                }
            }
        )
        }
    }

    // MARK: - Maintenance Plan Teaser (Pro keşfedilebilirliği)
    /// Dosya Skoru altında, "Bugün Garajında" üstünde.
    /// Free: kilit ikonu + paywall, Pro: işlevsel giriş.
    private func maintenancePlanTeaser(vehicle: Vehicle) -> some View {
        let canUse = paywallService.canUseAssistant
        return Button {
            if canUse {
                showMaintenancePlan = true
            } else {
                paywallFeature = .assistant
                showPaywall = true
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kişisel bakım planı")
                        .font(AppTypography.secondaryMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Yapay zekâ ile sana özel bakım önerileri")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: canUse ? "chevron.right" : "lock.fill")
                    .font(.caption)
                    .foregroundColor(canUse ? AppColors.textTertiary : AppColors.warning)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
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
                .cardShadow()
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
    /// Faz 2.6 — İlk araç eklendikten sonra rehber tanıtım banner'ı gösterilir.
    /// 7 günlük snooze: dismiss'ten 7 gün sonra yeniden gösterilebilir.
    private var shouldShowRehberIntro: Bool {
        guard !activeVehicles.isEmpty else { return false }
        let dismissedAt = Date(timeIntervalSince1970: guideIntroDismissedAt)
        if guideIntroDismissedAt == 0 { return true }
        return Date().timeIntervalSince(dismissedAt) > 7 * 24 * 60 * 60
    }

    private func dismissRehberIntro() {
        guideIntroDismissedAt = Date().timeIntervalSince1970
    }

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

    // MARK: - Akıllı Sürüş Asistanı
    /// Bir araç için predictive insight girdilerini hazırlar. Pro değilse .disabled döner.
    private func assistantInputs(for vehicle: Vehicle) -> VehicleInsightService.AssistantInputs {
        guard paywallService.canUseAssistant else { return .disabled }
        let profile = UsageProfileService.resolve(for: vehicle.id, from: allUsageProfiles)
        let estimate = PredictiveOdometerService.shared.estimate(
            lastKnownOdometer: vehicle.currentOdometer,
            lastKnownDate: vehicle.odometerIsEstimate ? nil : vehicle.lastOdometerUpdate,
            readings: odometerReadings(for: vehicle),
            profileBand: profile?.dailyKmBand
        )
        var suggestion: MaintenanceAdvisorService.Suggestion?
        if let profile {
            let dailyKm = estimate?.dailyKmAverage ?? Double(profile.dailyKmBand.midpointKm)
            let input = MaintenanceAdvisorService.Input(
                fuelType: vehicle.fuelType,
                vehicleYear: vehicle.year,
                currentOdometer: vehicle.currentOdometer,
                dailyKm: dailyKm,
                routeType: profile.routeType,
                dailyKmBand: profile.dailyKmBand,
                now: Date()
            )
            suggestion = MaintenanceAdvisorService.shared.topSuggestion(for: input)
        }
        return VehicleInsightService.AssistantInputs(
            enabled: true,
            odometerEstimate: estimate,
            maintenanceSuggestion: suggestion,
            usageProfileMissing: profile == nil && assistantProfilePrompted
        )
    }

    private func odometerReadings(for vehicle: Vehicle) -> [PredictiveOdometerService.Reading] {
        var readings: [PredictiveOdometerService.Reading] = []
        for e in expenses(for: vehicle) where e.odometer != nil {
            readings.append(.init(date: e.date, odometer: e.odometer!))
        }
        for s in services(for: vehicle) where s.odometer != nil {
            readings.append(.init(date: s.date, odometer: s.odometer!))
        }
        return readings
    }

    private func acceptEstimatedOdometer(for vehicle: Vehicle) {
        let profile = UsageProfileService.resolve(for: vehicle.id, from: allUsageProfiles)
        guard let estimate = PredictiveOdometerService.shared.estimate(
            lastKnownOdometer: vehicle.currentOdometer,
            lastKnownDate: vehicle.odometerIsEstimate ? nil : vehicle.lastOdometerUpdate,
            readings: odometerReadings(for: vehicle),
            profileBand: profile?.dailyKmBand
        ) else { return }
        Task {
            try? await VehicleContextRefreshService.updateCurrentOdometer(
                vehicle: vehicle,
                newOdometer: estimate.estimatedOdometer,
                isEstimate: true,
                context: modelContext
            )
        }
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
        case .acceptEstimatedOdometer:
            if let vehicle = currentVehicle { acceptEstimatedOdometer(for: vehicle) }
        case .openAssistantProfile:
            showAssistantProfile = true
        // Faz 1.1 — meta-aksiyonlar: kart kendisi dismiss eder, navigation yok.
        case .acknowledge, .dismissAndSnooze, .markAsRead, .noAction:
            break
        }
    }

    /// Faz 1.1 — kart dismiss edildiğinde hem dismiss hem snooze uygula.
    /// Dismiss kalıcıdır (tüm ekranlarda geçerli), snooze sürelidir.
    private func snoozeInsight(insight: VehicleInsight, vehicleId: UUID) {
        InsightSnoozeStore.shared.dismiss(insightType: insight.type, forVehicle: vehicleId)
        if let days = insight.snoozeDays, days > 0 {
            InsightSnoozeStore.shared.snooze(
                insightType: insight.type,
                forVehicle: vehicleId,
                days: days
            )
        }
        // Store ObservableObject olmadığı için manuel re-render tetikle
        insightDismissTrigger.toggle()
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
// Faz 1.1: GarageDailyInsightCard kaldırıldı — yerini VehicleInsightCard aldı.

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

// MARK: - Floating Quick Action Button (FAB)
// Garaj ekranında sağ alt köşede konumlanan dairesel buton.
// Basınca spring animasyonla 3 hızlı işlem butonu yukarı doğru açılır.
// Fiş/Fatura Tara free kullanıcıda Pro rozeti gösterir.
struct FloatingQuickActionButton: View {
    let onAddExpense: () -> Void
    let onScanReceipt: () -> Void
    let onAddReminder: () -> Void
    let showReceiptProBadge: Bool

    @State private var isExpanded = false
    private let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    var body: some View {
        ZStack {
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss() }
                    .accessibilityLabel("Kapat")
            }

            VStack(spacing: 12) {
                Spacer()

                if isExpanded {
                    fabAction(icon: "turkishlirasign.circle", label: "Masraf Ekle", color: AppColors.accentPrimary) {
                        dismiss()
                        onAddExpense()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    fabAction(icon: "doc.viewfinder", label: "Fiş/Fatura Tara", color: AppColors.accentPrimary, showProBadge: showReceiptProBadge) {
                        dismiss()
                        onScanReceipt()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    fabAction(icon: "bell.badge", label: "Hatırlatıcı Ekle", color: AppColors.success) {
                        dismiss()
                        onAddReminder()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button {
                    if isExpanded { dismiss() }
                    else { withAnimation(spring) { isExpanded = true } }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(AppColors.accentPrimary))
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                }
                .accessibilityLabel(isExpanded ? "Kapat" : "Hızlı İşlemler")
            }
            .padding(.trailing, AppSpacing.md)
            .padding(.bottom, AppSpacing.floatingTabBarContentInset - AppSpacing.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .animation(spring, value: isExpanded)
    }

    private func dismiss() {
        withAnimation(spring) { isExpanded = false }
    }

    private func fabAction(icon: String, label: String, color: Color, showProBadge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(AppTypography.secondaryMedium)
                    .foregroundColor(AppColors.textPrimary)
                if showProBadge {
                    Text("Pro")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.accentPrimary))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.appSurface).shadow(color: .black.opacity(0.2), radius: 6, y: 2))
        }
        .accessibilityLabel(showProBadge ? "\(label), Pro" : label)
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
