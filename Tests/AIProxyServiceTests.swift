import Foundation
import XCTest
@testable import Ruhsatim

// MARK: - AI Proxy Service Tests
// Hata eşleme (429 kota, .disabled, bozuk JSON) + result çıkarımı.
final class AIProxyServiceTests: XCTestCase {

    private struct StubConsent: AIConsentProviding {
        let enabled: Bool
        var isCloudAIEnabled: Bool { enabled }
    }

    private func data(_ s: String) -> Data { Data(s.utf8) }

    // MARK: mapResponse

    func testQuotaExceededMapsTo429() {
        let body = data(#"{"error":{"code":"quota_exceeded","task":"receipt_parse"}}"#)
        XCTAssertThrowsError(try AIProxyService.mapResponse(status: 429, data: body)) { error in
            XCTAssertEqual(error as? AIProxyError, .quotaExceeded(task: "receipt_parse"))
        }
    }

    func testUnauthorizedMapsTo401() {
        XCTAssertThrowsError(try AIProxyService.mapResponse(status: 401, data: data("{}"))) { error in
            XCTAssertEqual(error as? AIProxyError, .unauthorized)
        }
    }

    func testMissingProEntitlementMapsTo403() {
        XCTAssertThrowsError(try AIProxyService.mapResponse(status: 403, data: data("{}"))) { error in
            XCTAssertEqual(error as? AIProxyError, .proEntitlementRequired)
        }
    }

    func testUpstreamMapsForOther5xx() {
        XCTAssertThrowsError(try AIProxyService.mapResponse(status: 502, data: data("{}"))) { error in
            XCTAssertEqual(error as? AIProxyError, .upstream(status: 502))
        }
    }

    func testSuccessExtractsResult() throws {
        let body = data(#"{"result":{"a":1},"cached":false}"#)
        let resultData = try AIProxyService.mapResponse(status: 200, data: body)
        let decoded = try JSONDecoder().decode([String: Int].self, from: resultData)
        XCTAssertEqual(decoded["a"], 1)
    }

    func testMalformedSuccessWithoutResultThrows() {
        let body = data(#"{"cached":false}"#) // "result" yok
        XCTAssertThrowsError(try AIProxyService.mapResponse(status: 200, data: body)) { error in
            XCTAssertEqual(error as? AIProxyError, .malformedResponse)
        }
    }

    // MARK: decode

    func testDecodeReceiptSuccess() throws {
        let body = data(#"{"date":"15.03.2024","total":1079.5,"vendor":"OPET","odometer":null,"category":"fuel","isMaintenanceInvoice":false,"lineItems":[{"description":"MOTORIN","amount":1079.5}]}"#)
        let receipt = try AIProxyService.decode(ParsedReceiptAI.self, from: body)
        XCTAssertEqual(receipt.vendor, "OPET")
        XCTAssertEqual(receipt.total, 1079.5)
        XCTAssertEqual(receipt.lineItems.first?.description, "MOTORIN")
    }

    func testDecodeMalformedReceiptThrows() {
        // total String olarak geldi → Double decode başarısız → malformedResponse
        let body = data(#"{"date":"x","total":"NaN","vendor":"OPET","category":"fuel","isMaintenanceInvoice":false,"lineItems":[]}"#)
        XCTAssertThrowsError(try AIProxyService.decode(ParsedReceiptAI.self, from: body)) { error in
            XCTAssertEqual(error as? AIProxyError, .malformedResponse)
        }
    }

    func testDecodeMaintenanceArray() throws {
        let body = data(#"[{"title":"Triger","message":"kontrol","severity":"important","suggestedIntervalKm":5000,"suggestedIntervalMonths":null,"evidence":["121.000 km"],"confidence":"medium","recommendedAction":"Servis kaydını kontrol et","limitation":"Üretici planı bilinmiyor"}]"#)
        let plan = try AIProxyService.decode([MaintenancePlanSuggestion].self, from: body)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan.first?.severity, "important")
        XCTAssertEqual(plan.first?.suggestedIntervalKm, 5000)
        XCTAssertNil(plan.first?.suggestedIntervalMonths)
        XCTAssertEqual(plan.first?.confidence, "medium")
        XCTAssertEqual(plan.first?.evidence, ["121.000 km"])
    }

    // MARK: kill-switch

    func testCompleteThrowsDisabledWhenConsentOff() async {
        let service = AIProxyService(consent: StubConsent(enabled: false))
        do {
            _ = try await service.complete(task: .receiptParse, payload: "herhangi bir metin")
            XCTFail("beklenen .disabled")
        } catch let error as AIProxyError {
            XCTAssertEqual(error, .disabled)
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
    }

    func testCompletePayloadTooLargeBeforeNetwork() async {
        // Consent açık ama payload 20k sınırını aşıyor → ağ'a çıkmadan payloadTooLarge.
        let service = AIProxyService(
            consent: StubConsent(enabled: true),
            configProvider: { AIProxyConfig(baseURL: URL(string: "https://example.com")!, clientSecret: "x") }
        )
        let huge = String(repeating: "a", count: 20_001)
        do {
            _ = try await service.complete(task: .receiptParse, payload: huge)
            XCTFail("beklenen .payloadTooLarge")
        } catch let error as AIProxyError {
            XCTAssertEqual(error, .payloadTooLarge)
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
    }

    func testCompleteRequiresVerifiedTransactionBeforeNetwork() async {
        let service = AIProxyService(
            consent: StubConsent(enabled: true),
            configProvider: { AIProxyConfig(baseURL: URL(string: "https://example.com")!, clientSecret: "x") },
            proTransactionIDProvider: { nil }
        )
        do {
            _ = try await service.complete(task: .maintenancePlan, payload: "{}")
            XCTFail("beklenen .transactionUnavailable")
        } catch let error as AIProxyError {
            XCTAssertEqual(error, .transactionUnavailable)
        } catch {
            XCTFail("beklenmeyen hata: \(error)")
        }
    }
}
