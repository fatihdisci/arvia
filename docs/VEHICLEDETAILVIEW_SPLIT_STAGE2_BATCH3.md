# VehicleDetailView.swift — Stage 2 Batch 3: Vehicle Life Timeline Extraction

**Tarih:** 2026-07-04
**Amaç:** `VehicleDetailView` içindeki `lifeTimelineSection` + 3 helper'ını (`TimelineEvent`, `buildTimelineEvents()`, `timelineItem`) `LifeTimelineSection` adlı bağımsız subview'a çıkarmak.

---

## 1. Oluşturulan Dosya

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/LifeTimelineSection.swift` | 316 |

## 2. plutil -lint

**OK** — geçti.

## 3. Build

**BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**1204 satır** (1504 → 1204, −300 satır).

Toplamda: 2049 → 1204 (−845 satır, %41 azalma).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/InspectionReportSection.swift     ← Batch 2.1
?? Features/VehicleDetail/LifeTimelineSection.swift         ← yeni (Batch 2.3)
?? Features/VehicleDetail/RecentRecordItem.swift            ← Stage 1
?? Features/VehicleDetail/RecentRecordsSection.swift        ← Batch 2.1
?? Features/VehicleDetail/SaleFilePreviewCard.swift         ← Batch 2.1
?? Features/VehicleDetail/UpcomingTaskCard.swift            ← Stage 1
?? Features/VehicleDetail/VehicleDetailMilestoneCard.swift  ← Stage 1
?? Features/VehicleDetail/VehicleQuickActionsSection.swift  ← Batch 2.2
?? docs/ARVIA_APP_ICON_PROMPT.md                           (önceden mevcut)
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH1.md           ← Batch 2.1 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH2.md           ← Batch 2.2 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STEP1.md                   ← Stage 1 raporu
```

---

## Yeni Struct

```swift
struct LifeTimelineSection: View {
    let vehicle: Vehicle
    let serviceRecords: [ServiceRecord]
    let expenses: [Expense]
    let inspectionReports: [InspectionReport]
    let saleFiles: [SaleFile]
    // ...
}
```

Tamamen read-only, hiçbir closure yok — bu section'da user interaction bulunmuyor. 4 private member (view + helper + nested type) birlikte taşındı. `TimelineEvent` `VehicleDetailMilestoneCard.MilestoneKind`'e referans veriyor, aynı target içinde cross-file çalışıyor (Stage 1'de çıkarılmıştı).
