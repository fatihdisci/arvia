# VehicleDetailView.swift — Stage 2 Batch 1: Subview Extraction

**Tarih:** 2026-07-04
**Amaç:** `VehicleDetailView` struct'ı içindeki 3 MARK-section'lu view member'ı kendi dosyalarına çıkarmak (pure relocation, plain `let` + `() -> Void` closure pattern).

---

## 1. Oluşturulan 3 Dosya

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/SaleFilePreviewCard.swift` | 50 |
| 2 | `Features/VehicleDetail/RecentRecordsSection.swift` | 116 |
| 3 | `Features/VehicleDetail/InspectionReportSection.swift` | 94 |

## 2. plutil -lint

Her pbxproj düzenlemesinden sonra geçti: **3/3 OK**.

## 3. Build Başarısı

Her adımdan sonra build alındı:

- Step 1 (SaleFilePreviewCard): **BUILD SUCCEEDED**
- Step 2 (RecentRecordsSection): **BUILD SUCCEEDED**
- Step 3 (InspectionReportSection): **BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**1564 satır** (1805 → 1564, −241 satır).

Toplamda Stage 1 + Stage 2 Batch 1: 2049 → 1564 (−485 satır, %24 azalma).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/InspectionReportSection.swift     ← yeni (Stage 2)
?? Features/VehicleDetail/RecentRecordItem.swift            ← Stage 1
?? Features/VehicleDetail/RecentRecordsSection.swift        ← yeni (Stage 2)
?? Features/VehicleDetail/SaleFilePreviewCard.swift         ← yeni (Stage 2)
?? Features/VehicleDetail/UpcomingTaskCard.swift            ← Stage 1
?? Features/VehicleDetail/VehicleDetailMilestoneCard.swift  ← Stage 1
?? docs/ARVIA_APP_ICON_PROMPT.md                           (önceden mevcut)
?? docs/VEHICLEDETAILVIEW_SPLIT_STEP1.md                   ← Stage 1 raporu
```

---

## Yeni Subview Pattern'i

Her üç yeni struct da aynı "dumb view" pattern'ini kullanır:

```swift
struct XxxSection: View {
    let data: [SomeType]          // plain let, @Binding/@Environment yok
    let onAction: () -> Void      // user-interaction closure
    var body: some View { ... }
}
```

Parent `VehicleDetailView` tüm state'i sahiplenmeye devam eder, alt view'lara sadece data ve closure geçer.

## Notlar

- `RecentRecordsSection`: `recentRecords()` ve `recentRecordRow(_:)` helper'ları da taşındı, struct'ın private member'ları oldu.
- `SectionHeader`'daki boş `action: {}` korundu (önceden var olan gap, bu task'ın kapsamı dışında).
- `InspectionReportSection`: `handleAddInspection()` → `onAddInspection()` closure.
- `SaleFilePreviewCard`: `handleSaleFileTap()` → `onTap()` closure.
- Bug fix: Sources build phase'deki ID `BB11CC22DD33EE55AA6601` ilk denemede eksik yazılmıştı (`BB11CC22DD33EE55AA6601`), düzeltildi.
