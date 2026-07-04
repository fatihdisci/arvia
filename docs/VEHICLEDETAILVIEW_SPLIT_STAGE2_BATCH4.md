# VehicleDetailView.swift — Stage 2 Batch 4: Documents Section Extraction

**Tarih:** 2026-07-04
**Amaç:** `VehicleDetailView` içindeki `documentsSection` + 3 helper'ını (`documentRow`, `previewDocument`, `deleteDocument`) `DocumentsSection` adlı bağımsız subview'a çıkarmak.

---

## 1. Oluşturulan Dosya

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/DocumentsSection.swift` | 169 |

## 2. plutil -lint

**OK** — geçti.

## 3. Build

**BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**1050 satır** (1204 → 1050, −154 satır).

Toplamda: 2049 → 1050 (−999 satır, %49 azalma).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/DocumentsSection.swift            ← yeni (Batch 2.4)
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
?? docs/VEHICLEDETAILVIEW_SPLIT_STEP1.md                   ← Stage 1 raporu
```

---

## Yeni Struct

```swift
struct DocumentsSection: View {
    let documents: [VehicleDocument]
    @Binding var previewDocumentURL: URL?       // parent @State'a write-back
    @Binding var showDocumentPreview: Bool      // vestigial ama korundu
    let onAddDocument: () -> Void

    @Environment(\.modelContext) private var modelContext  // direct @Environment
    // ...
}
```

Bu batch'te diğerlerinden farklı olarak 2 adet `@Binding` kullanıldı — `previewDocumentURL` parent'taki `.quickLookPreview($previewDocumentURL)` modifier'ına bağlı olduğu için, `showDocumentPreview` ise halihazırda hiçbir yerde okunmayan (vestigial) state olduğu için verbatim korundu. `modelContext` parametre olarak değil `@Environment` üzerinden alındı.
