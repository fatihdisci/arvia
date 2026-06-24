import UIKit
import PDFKit

// MARK: - PDF Export Service
// Satış dosyası PDF'i oluşturur.
// Premium, güvenilir, temiz tasarım. Dekoratif karmaşa yok.

final class PDFExportService {

    struct PDFData {
        let vehicle: Vehicle
        let serviceRecords: [ServiceRecord]
        let expenses: [Expense]
        let inspectionReports: [InspectionReport]
        let documents: [VehicleDocument]
        let includedSections: [SaleFileSection]
        let includeExpenseSummary: Bool
    }

    // MARK: - Page metrics
    private let pageWidth: CGFloat = 595.2  // A4
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 48
    private var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - Generate
    func generatePDF(data: PDFData) -> URL {
        let fileName = "SatisDosyasi-\(data.vehicle.id.uuidString.prefix(8)).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        try? renderer.writePDF(to: outputURL) { context in
            // Kapak
            context.beginPage()
            drawCover(context: context, data: data)

            // Araç Özeti
            if data.includedSections.contains(.summary) {
                context.beginPage()
                drawVehicleSummary(context: context, data: data)
            }

            // Bakım Geçmişi
            if data.includedSections.contains(.serviceHistory), !data.serviceRecords.isEmpty {
                context.beginPage()
                drawServiceHistory(context: context, data: data)
            }

            // Masraf Özeti
            if data.includeExpenseSummary, !data.expenses.isEmpty {
                context.beginPage()
                drawExpenseSummary(context: context, data: data)
            }

            // Ekspertiz Raporu
            if data.includedSections.contains(.inspectionReports), !data.inspectionReports.isEmpty {
                context.beginPage()
                drawInspectionReports(context: context, data: data)
            }

            // Belgeler
            if data.includedSections.contains(.documents), !data.documents.isEmpty {
                context.beginPage()
                drawDocumentsList(context: context, data: data)
            }

            // Yasal Uyarı
            if data.includedSections.contains(.disclaimer) {
                context.beginPage()
                drawDisclaimer(context: context)
            }
        }

        return outputURL
    }

    // MARK: - Cover Page
    private func drawCover(context: UIGraphicsPDFRendererContext, data: PDFData) {
        let v = data.vehicle
        var y: CGFloat = pageHeight / 2 - 120

        // Title
        let title = "Satış Dosyası"
        drawCenteredText(title, at: y, font: .systemFont(ofSize: 28, weight: .light), color: .darkGray)
        y += 50

        // Vehicle name
        drawCenteredText(v.fullName, at: y, font: .systemFont(ofSize: 22, weight: .semibold), color: .black)
        y += 35

        // Plate
        drawCenteredText(v.plate, at: y, font: UIFont.monospacedSystemFont(ofSize: 32, weight: .bold), color: UIColor(red: 0.06, green: 0.47, blue: 0.43, alpha: 1))
        y += 45

        // Date
        let dateStr = Date().formatted(date: .long, time: .omitted)
        drawCenteredText(dateStr, at: y, font: .systemFont(ofSize: 12, weight: .regular), color: .gray)

        // Footer: app name
        drawCenteredText("Ruhsatım — Aracının Dijital Dosyası", at: pageHeight - margin - 20, font: .systemFont(ofSize: 10, weight: .light), color: .lightGray)
    }

    // MARK: - Vehicle Summary
    private func drawVehicleSummary(context: UIGraphicsPDFRendererContext, data: PDFData) {
        let v = data.vehicle
        var y = drawSectionHeader("Araç Özeti", at: margin)

        let items: [(String, String)] = [
            ("Plaka", v.plate),
            ("Marka", v.brand),
            ("Model", v.model),
            ("Yıl", v.yearDisplay),
            ("Km", v.odometerDisplay),
            ("Yakıt", v.fuelType.displayName),
            ("Vites", v.transmissionType?.displayName ?? "—"),
        ]

        for (label, value) in items {
            drawKeyValue(label: label, value: value, at: y)
            y += 24
        }

        if let purchaseDate = v.purchaseDate {
            y += 8
            drawKeyValue(label: "Satın Alma", value: purchaseDate.formatted(date: .abbreviated, time: .omitted), at: y)
            y += 24
        }

        if let price = v.purchasePriceDisplay {
            drawKeyValue(label: "Satın Alma Fiyatı", value: price, at: y)
        }
    }

    // MARK: - Service History
    private func drawServiceHistory(context: UIGraphicsPDFRendererContext, data: PDFData) {
        var y = drawSectionHeader("Bakım Geçmişi", at: margin)

        for record in data.serviceRecords.sorted(by: { $0.date > $1.date }).prefix(15) {
            // Check page break
            if y > pageHeight - 100 {
                context.beginPage()
                y = margin
            }

            let title = "\(record.serviceType.displayName) — \(record.dateDisplay)"
            drawText(title, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
            y += 20

            if let vendor = record.vendorName, !vendor.isEmpty {
                drawText(vendor, at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .darkGray)
                y += 16
            }
            if let cost = record.totalCostDisplay {
                drawText("Tutar: \(cost)", at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .darkGray)
                y += 16
            }
            if let km = record.odometerDisplay {
                drawText("Km: \(km)", at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .gray)
                y += 16
            }

            y += 10
        }
    }

    // MARK: - Expense Summary
    private func drawExpenseSummary(context: UIGraphicsPDFRendererContext, data: PDFData) {
        var y = drawSectionHeader("Masraf Özeti", at: margin)

        let total = data.expenses.reduce(0) { $0 + $1.amount }
        let yearly = data.expenses
            .filter { Calendar.current.component(.year, from: $0.date) == Calendar.current.component(.year, from: Date()) }
            .reduce(0) { $0 + $1.amount }

        drawKeyValue(label: "Bu Yıl Toplam", value: formatTRY(yearly), at: y); y += 28
        drawKeyValue(label: "Genel Toplam", value: formatTRY(total), at: y); y += 28

        y += 12
        drawText("Kategori Dağılımı", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
        y += 22

        var dict: [ExpenseCategory: Double] = [:]
        for e in data.expenses { dict[e.category, default: 0] += e.amount }
        for (cat, amount) in dict.sorted(by: { $0.value > $1.value }).prefix(8) {
            drawText("\(cat.displayName): \(formatTRY(amount))", at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .darkGray)
            y += 18
        }
    }

    // MARK: - Inspection Reports
    private func drawInspectionReports(context: UIGraphicsPDFRendererContext, data: PDFData) {
        var y = drawSectionHeader("Ekspertiz Raporu", at: margin)

        for report in data.inspectionReports.prefix(3) {
            if y > pageHeight - 100 { context.beginPage(); y = margin }

            drawText(report.providerName, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 14, weight: .semibold), color: .black)
            y += 20
            if let branch = report.branchName, !branch.isEmpty {
                drawText(branch, at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .darkGray)
                y += 16
            }
            drawText("Tarih: \(report.dateDisplay)", at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .gray)
            y += 16

            if !report.summary.isEmpty {
                drawWrappedText(report.summary, at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 10, weight: .regular), color: .darkGray, maxWidth: contentWidth - 12)
                y += estimateTextHeight(report.summary, font: .systemFont(ofSize: 10), maxWidth: contentWidth - 12) + 10
            }

            drawText("Durum: \(report.verificationStatus.displayName)", at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 10, weight: .regular), color: .gray)
            y += 24
        }

        y += 8
        drawWrappedText(InspectionReport.legalDisclaimer, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 9, weight: .regular), color: .lightGray, maxWidth: contentWidth)
    }

    // MARK: - Documents List
    private func drawDocumentsList(context: UIGraphicsPDFRendererContext, data: PDFData) {
        var y = drawSectionHeader("Belgeler", at: margin)

        for doc in data.documents {
            if y > pageHeight - 60 { context.beginPage(); y = margin }
            drawText("• \(doc.title.isEmpty ? doc.type.displayName : doc.title) (\(doc.type.displayName))", at: CGPoint(x: margin + 8, y: y), font: .systemFont(ofSize: 11, weight: .regular), color: .darkGray)
            y += 18
        }
    }

    // MARK: - Disclaimer
    private func drawDisclaimer(context: UIGraphicsPDFRendererContext) {
        let y = drawSectionHeader("Hukuki Uyarı", at: margin)

        drawWrappedText(SaleFile.legalDisclaimer, at: CGPoint(x: margin, y: y + 10), font: .systemFont(ofSize: 10, weight: .regular), color: .darkGray, maxWidth: contentWidth)

        let footerY = pageHeight - margin - 20
        drawCenteredText("Bu dosya Ruhsatım uygulaması tarafından oluşturulmuştur.", at: footerY, font: .systemFont(ofSize: 9, weight: .light), color: .lightGray)
    }

    // MARK: - Drawing Helpers
    private func drawSectionHeader(_ title: String, at yPos: CGFloat) -> CGFloat {
        var y = yPos
        drawText(title, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 20, weight: .light), color: UIColor(red: 0.06, green: 0.47, blue: 0.43, alpha: 1))
        y += 35

        // Divider
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: margin, y: y))
        dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor.lightGray.withAlphaComponent(0.3).setStroke()
        dividerPath.lineWidth = 1
        dividerPath.stroke()

        return y + 16
    }

    private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private func drawCenteredText(_ text: String, at y: CGFloat, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        let x = (pageWidth - size.width) / 2
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
    }

    private func drawWrappedText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, maxWidth: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: .greatestFiniteMagnitude)
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
    }

    private func drawKeyValue(label: String, value: String, at y: CGFloat) {
        drawText(label, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 12, weight: .medium), color: .gray)
        drawText(value, at: CGPoint(x: margin + 140, y: y), font: .systemFont(ofSize: 12, weight: .regular), color: .black)
    }

    private func estimateTextHeight(_ text: String, font: UIFont, maxWidth: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        )
        return rect.height
    }

    private func formatTRY(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "TRY"
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: value)) ?? "₺0"
    }
}
