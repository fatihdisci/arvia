# VehicleDetailView.swift — Stage 2 Batch 5: Current Status Section Extraction

**Tarih:** 2026-07-04
**Amaç:** `VehicleDetailView` içindeki `currentStatusSection` + `monthlySummaryCard` + `nextTasksCard` + `priorityColor` 4 üyesini `CurrentStatusSection` adlı bağımsız subview'a çıkarmak.

---

## 1. Oluşturulan Dosya

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/CurrentStatusSection.swift` | 192 |

## 2. plutil -lint

**OK** — geçti.

## 3. Build

**BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**873 satır** (1050 → 873, −177 satır).

Toplamda: 2049 → 873 (−1176 satır, %57 azalma).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/CurrentStatusSection.swift        ← yeni (Batch 2.5)
?? Features/VehicleDetail/DocumentsSection.swift            ← Batch 2.4
?? Features/VehicleDetail/InspectionReportSection.swift     ← Batch 2.1
?? Features/VehicleDetail/LifeTimelineSection.swift         ← Batch 2.3
?? Features/VehicleDetail/RecentRecordItem.swift            ← Stage 1
?? Features/VehicleDetail/RecentRecordsSection.swift        ← Batch 2.1
?? Features/VehicleDetail/SaleFilePreviewCard.swift         ← Batch 2.1
?? Features/VehicleDetail/UpcomingTaskCard.swift            ← Stage 1
?? Features/VehicleDetail/VehicleDetailMilestoneCard.swift  ← Stage 1
?? Features/VehicleDetail/VehicleQuickActionsSection.swift  ← Batch 2.2
?? docs/ARVIA_APP_ICON_PROMPT.md                           (önceden mevcut)
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH1.md           ← Batch 2.1 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH2.md           ← Batch 2.2 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH3.md           ← Batch 2.3 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH4.md           ← Batch 2.4 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STEP1.md                   ← Stage 1 raporu
```

---

## Yeni Struct

```swift
struct CurrentStatusSection: View {
    let expenses: [Expense]
    let upcomingTasks: [VehicleUpcomingTask]
    let onAddExpense: () -> Void

    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    // ...
}
```

Non-contiguous extraction: `currentStatusSection` + `monthlySummaryCard` + `nextTasksCard` tek blok halinde, `priorityColor(_:)` ise ayrı bir blok olarak (`notificationRouteBanner`'ın altından) kesilip aynı dosyaya eklendi. `navigationRouter` `@EnvironmentObject` olarak doğrudan alındı, `upcomingTasks` parent'ta computed property olarak kaldı, sadece sonuç dizisi parametre olarak geçildi.

## notificationRouteBanner Kontrolü

`notificationRouteBanner` halen `VehicleDetailView.swift` içinde, değiştirilmeden duruyor (tanım + call site). Bu batch'ten etkilenmedi.
