import Foundation
import Supabase

// MARK: - Community Profile Service
// Supabase profiles tablosu CRUD işlemleri.

@MainActor
final class CommunityProfileService {
    static let shared = CommunityProfileService()

    private var client: SupabaseClient? {
        SupabaseClientProvider.shared.client
    }

    // MARK: - Fetch

    /// Kullanıcının profilini getir.
    func fetchProfile(userId: UUID) async throws -> CommunityProfile? {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let response: [CommunityProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    /// Kullanıcı adı ile profil ara.
    func fetchProfileByUsername(_ username: String) async throws -> CommunityProfile? {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let response: [CommunityProfile] = try await client
            .from("profiles")
            .select()
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    // MARK: - Create

    /// Yeni profil oluştur. userId = auth.users.id.
    func createProfile(
        userId: UUID,
        username: String,
        displayName: String? = nil
    ) async throws -> CommunityProfile {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let payload: JSONObject = [
            "id": AnyJSON.string(userId.uuidString),
            "username": AnyJSON.string(username),
            "display_name": displayName.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "show_vehicle_on_posts": AnyJSON.bool(false),
        ]

        let response: CommunityProfile = try await client
            .from("profiles")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    // MARK: - Update

    /// Profil güncelle.
    func updateProfile(
        userId: UUID,
        username: String,
        displayName: String?,
        defaultVehicleBrand: String?,
        defaultVehicleModel: String?,
        defaultVehicleYear: Int?,
        showVehicleOnPosts: Bool
    ) async throws -> CommunityProfile {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let payload: JSONObject = [
            "username": AnyJSON.string(username),
            "display_name": displayName.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "default_vehicle_brand": defaultVehicleBrand.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "default_vehicle_model": defaultVehicleModel.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "default_vehicle_year": defaultVehicleYear.map { AnyJSON.integer($0) } ?? AnyJSON.null,
            "show_vehicle_on_posts": AnyJSON.bool(showVehicleOnPosts),
        ]

        let response: CommunityProfile = try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    // MARK: - Username Check

    /// Kullanıcı adı müsait mi? (debounce için)
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let count = try await client
            .from("profiles")
            .select("*", head: true, count: .exact)
            .eq("username", value: username)
            .execute()
            .count

        return count == 0
    }
}

// MARK: - Errors

enum CommunityServiceError: Error, LocalizedError {
    case configMissing
    case notAuthenticated
    case noProfile
    case networkError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .configMissing:
            return "Topluluk bağlantısı yapılandırılmamış."
        case .notAuthenticated:
            return "Bu işlem için giriş yapmalısın."
        case .noProfile:
            return "Önce profilini oluşturmalısın."
        case .networkError(let msg):
            return "Bağlantı hatası: \(msg)"
        case .serverError(let msg):
            return "Sunucu hatası: \(msg)"
        }
    }
}
