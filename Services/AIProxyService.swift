import Foundation

// MARK: - AI Proxy Service
// Vercel edge proxy'ye ince async istemci. Model anahtarı cihazda TUTULMAZ;
// istekler proxy üzerinden gider. Kill-switch: consent kapalıysa .disabled fırlatır
// ve çağıran taraf sessizce yerel davranışa döner.

// MARK: - Task
enum AITask: String {
    case receiptParse = "receipt_parse"
    case maintenancePlan = "maintenance_plan"
}

// MARK: - Typed responses
struct ParsedReceiptAI: Codable, Equatable {
    let date: String?
    let total: Double?
    let vendor: String?
    let odometer: Int?
    let category: String?
    let isMaintenanceInvoice: Bool
    let lineItems: [LineItem]

    struct LineItem: Codable, Equatable {
        let description: String
        let amount: Double
    }
}

struct MaintenancePlanSuggestion: Codable, Equatable {
    let title: String
    let message: String
    let severity: String
    let suggestedIntervalKm: Int?
    let suggestedIntervalMonths: Int?
}

// MARK: - Errors
enum AIProxyError: Error, Equatable {
    case disabled            // consent kapalı / toggle off — sessiz yerel fallback
    case notConfigured       // proxy URL/secret eksik
    case payloadTooLarge
    case quotaExceeded(task: String?)
    case unauthorized
    case proEntitlementRequired
    case receiptUnavailable
    case malformedResponse
    case upstream(status: Int)
    case transport
}

// MARK: - Consent
protocol AIConsentProviding {
    /// Yalnızca ana toggle açık VE kullanıcı onayı alınmışsa true.
    var isCloudAIEnabled: Bool { get }
}

/// UserDefaults tabanlı consent kaynağı. Ayarlar ekranı @AppStorage ile aynı
/// anahtarları kullanır (ai_cloud_enabled / ai_consent_accepted).
final class AIConsentStore: AIConsentProviding {
    static let shared = AIConsentStore()
    static let enabledKey = "ai_cloud_enabled"
    static let consentKey = "ai_consent_accepted"

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isCloudEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }
    var hasConsented: Bool { defaults.bool(forKey: Self.consentKey) }
    var isCloudAIEnabled: Bool { isCloudEnabled && hasConsented }
}

// MARK: - Config (plist/xcconfig — hardcode YOK)
struct AIProxyConfig {
    let baseURL: URL
    let clientSecret: String

    static func load() -> AIProxyConfig? {
        // Trim whitespace/newlines defensively — a stray trailing space or line
        // break picked up while editing Config.xcconfig would otherwise make the
        // client secret silently mismatch the server's value (401 unauthorized)
        // even though both "look" identical when eyeballed.
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "ARVIA_AI_PROXY_URL") as? String else {
            return nil
        }
        let urlString = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, !urlString.contains("YOUR-"),
              let url = URL(string: urlString),
              let rawSecret = Bundle.main.object(forInfoDictionaryKey: "ARVIA_AI_CLIENT_SECRET") as? String else {
            return nil
        }
        let secret = rawSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty, !secret.contains("YOUR_") else {
            return nil
        }
        return AIProxyConfig(baseURL: url, clientSecret: secret)
    }
}

// MARK: - Service
final class AIProxyService {
    static let shared = AIProxyService()

    private let session: URLSession
    private let consent: AIConsentProviding
    private let configProvider: () -> AIProxyConfig?
    private let appReceiptProvider: () -> String?

    init(
        session: URLSession = .shared,
        consent: AIConsentProviding = AIConsentStore.shared,
        configProvider: @escaping () -> AIProxyConfig? = { AIProxyConfig.load() },
        appReceiptProvider: @escaping () -> String? = { AIProxyService.currentAppReceipt() }
    ) {
        self.session = session
        self.consent = consent
        self.configProvider = configProvider
        self.appReceiptProvider = appReceiptProvider
    }

    private static let maxPayloadChars = 20_000

    // MARK: Typed convenience
    func parseReceipt(ocrText: String) async throws -> ParsedReceiptAI {
        let data = try await complete(task: .receiptParse, payload: ocrText)
        return try Self.decode(ParsedReceiptAI.self, from: data)
    }

    func maintenancePlan(profileJSON: String) async throws -> [MaintenancePlanSuggestion] {
        let data = try await complete(task: .maintenancePlan, payload: profileJSON)
        return try Self.decode([MaintenancePlanSuggestion].self, from: data)
    }

    // MARK: Core
    /// Proxy'ye istek atar ve `result` alt-JSON'unu Data olarak döndürür.
    /// Consent kapalıysa ağ'a çıkmadan .disabled fırlatır.
    @discardableResult
    func complete(task: AITask, payload: String) async throws -> Data {
        guard consent.isCloudAIEnabled else { throw AIProxyError.disabled }
        guard payload.count <= Self.maxPayloadChars else { throw AIProxyError.payloadTooLarge }
        guard let config = configProvider() else { throw AIProxyError.notConfigured }
        guard let appReceipt = appReceiptProvider() else { throw AIProxyError.receiptUnavailable }

        var request = URLRequest(url: config.baseURL.appendingPathComponent("api/complete"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.clientSecret, forHTTPHeaderField: "X-Arvia-Client")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                task: task.rawValue,
                payload: payload,
                appReceipt: appReceipt
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIProxyError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw AIProxyError.transport }
        return try Self.mapResponse(status: http.statusCode, data: data)
    }

    // MARK: - Testable mapping / decoding
    /// HTTP durumunu tipli hataya çevirir; 2xx'te `result` alt-JSON Data'sını döndürür.
    static func mapResponse(status: Int, data: Data) throws -> Data {
        switch status {
        case 200..<300:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = object["result"] else {
                throw AIProxyError.malformedResponse
            }
            guard JSONSerialization.isValidJSONObject(result),
                  let resultData = try? JSONSerialization.data(withJSONObject: result) else {
                throw AIProxyError.malformedResponse
            }
            return resultData
        case 401:
            throw AIProxyError.unauthorized
        case 403:
            throw AIProxyError.proEntitlementRequired
        case 429:
            let task = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.task
            throw AIProxyError.quotaExceeded(task: task)
        default:
            throw AIProxyError.upstream(status: status)
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AIProxyError.malformedResponse
        }
    }

    // MARK: - Wire types
    private struct RequestBody: Encodable {
        let task: String
        let payload: String
        let appReceipt: String
    }

    private struct ErrorBody: Decodable {
        struct Inner: Decodable { let code: String; let task: String? }
        let error: Inner
    }

    private static func currentAppReceipt() -> String? {
        guard let url = Bundle.main.appStoreReceiptURL,
              let data = try? Data(contentsOf: url),
              !data.isEmpty else {
            return nil
        }
        return data.base64EncodedString()
    }
}
