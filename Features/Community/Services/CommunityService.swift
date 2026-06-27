import Foundation
import Supabase

// MARK: - Community Service
// Topluluk gönderileri ve yorumları için Supabase CRUD işlemleri.

@MainActor
final class CommunityService {
    static let shared = CommunityService()

    private var client: SupabaseClient? {
        SupabaseClientProvider.shared.client
    }

    private let pageSize = 20

    // MARK: - Fetch Posts

    /// Gönderileri sayfalandırarak getir. Filtreleme parametreleri opsiyoneldir.
    func fetchPosts(
        type: PostType? = nil,
        tags: [String] = [],
        brand: String? = nil,
        model: String? = nil,
        page: Int = 0
    ) async throws -> [CommunityPost] {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        // Önce düz select dene — join olmadan, decode garantili.
        let posts: [CommunityPost] = try await client
            .from("community_posts")
            .select("*")
            .eq("is_hidden", value: false)
            .is("deleted_at", value: nil)
            .order("is_pinned", ascending: false)
            .order("created_at", ascending: false)
            .range(from: page * pageSize, to: (page + 1) * pageSize - 1)
            .execute()
            .value

        // Filtreleri client-side uygula (join olmadığı için server-side filtre limitli)
        var result = posts
        if let type = type {
            result = result.filter { $0.postType == type }
        }
        if !tags.isEmpty {
            result = result.filter { post in tags.allSatisfy { post.tags.contains($0) } }
        }
        if let brand = brand, !brand.isEmpty {
            result = result.filter { $0.vehicleBrand == brand }
        }
        if let model = model, !model.isEmpty {
            result = result.filter { $0.vehicleModel == model }
        }
        return result
    }

    /// Tek bir gönderiyi getir.
    func fetchPost(id: UUID) async throws -> CommunityPost? {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let posts: [CommunityPost] = try await client
            .from("community_posts")
            .select("*")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return posts.first
    }

    // MARK: - Create / Update / Delete Post

    func createPost(
        title: String,
        body: String,
        postType: PostType,
        tags: [String],
        vehicleBrand: String? = nil,
        vehicleModel: String? = nil,
        vehicleYear: Int? = nil
    ) async throws {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard let session = try? await client.auth.session else {
            throw CommunityServiceError.notAuthenticated
        }

        let payload: JSONObject = [
            "author_id": AnyJSON.string(session.user.id.uuidString),
            "title": AnyJSON.string(title),
            "body": AnyJSON.string(body),
            "post_type": AnyJSON.string(postType.rawValue),
            "tags": .array(tags.map { AnyJSON.string($0) }),
            "vehicle_brand": vehicleBrand.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "vehicle_model": vehicleModel.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "vehicle_year": vehicleYear.map { AnyJSON.integer($0) } ?? AnyJSON.null,
        ]

        // Insert only — don't decode response (joined kolonlar dönmediği için decode başarısız olmaz).
        try await client
            .from("community_posts")
            .insert(payload)
            .execute()
    }

    func updatePost(
        id: UUID,
        title: String,
        body: String,
        postType: PostType,
        tags: [String],
        vehicleBrand: String?,
        vehicleModel: String?,
        vehicleYear: Int?
    ) async throws {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        let payload: JSONObject = [
            "title": AnyJSON.string(title),
            "body": AnyJSON.string(body),
            "post_type": AnyJSON.string(postType.rawValue),
            "tags": .array(tags.map { AnyJSON.string($0) }),
            "vehicle_brand": vehicleBrand.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "vehicle_model": vehicleModel.map { AnyJSON.string($0) } ?? AnyJSON.null,
            "vehicle_year": vehicleYear.map { AnyJSON.integer($0) } ?? AnyJSON.null,
        ]

        try await client
            .from("community_posts")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Soft delete — yazar kendi gönderisini siler.
    func deletePost(id: UUID) async throws {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard let session = try? await client.auth.session else {
            throw CommunityServiceError.notAuthenticated
        }

        let payload: JSONObject = [
            "deleted_at": AnyJSON.string(Date().ISO8601Format()),
            "deleted_by": AnyJSON.string(session.user.id.uuidString),
        ]

        try await client
            .from("community_posts")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Likes

    func toggleLike(postId: UUID) async throws -> Bool {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard let session = try? await client.auth.session else {
            throw CommunityServiceError.notAuthenticated
        }

        let userId = session.user.id.uuidString

        // Check if already liked
        let existing: [EmptyResponse] = try await client
            .from("community_post_likes")
            .select("*")
            .eq("post_id", value: postId.uuidString)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        if existing.isEmpty {
            // Like
            try await client
                .from("community_post_likes")
                .insert([
                    "post_id": AnyJSON.string(postId.uuidString),
                    "user_id": AnyJSON.string(userId),
                ])
                .execute()
            return true
        } else {
            // Unlike
            try await client
                .from("community_post_likes")
                .delete()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId)
                .execute()
            return false
        }
    }

    // MARK: - Saves

    func toggleSave(postId: UUID) async throws -> Bool {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard let session = try? await client.auth.session else {
            throw CommunityServiceError.notAuthenticated
        }

        let userId = session.user.id.uuidString

        let existing: [EmptyResponse] = try await client
            .from("community_post_saves")
            .select("*")
            .eq("post_id", value: postId.uuidString)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        if existing.isEmpty {
            try await client
                .from("community_post_saves")
                .insert([
                    "post_id": AnyJSON.string(postId.uuidString),
                    "user_id": AnyJSON.string(userId),
                ])
                .execute()
            return true
        } else {
            try await client
                .from("community_post_saves")
                .delete()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId)
                .execute()
            return false
        }
    }

    // MARK: - Comments

    func fetchComments(postId: UUID) async throws -> [CommunityComment] {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        return try await client
            .from("community_comments")
            .select("*")
            .eq("post_id", value: postId.uuidString)
            .eq("is_hidden", value: false)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createComment(postId: UUID, body: String) async throws {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard let session = try? await client.auth.session else {
            throw CommunityServiceError.notAuthenticated
        }

        let payload: JSONObject = [
            "post_id": AnyJSON.string(postId.uuidString),
            "author_id": AnyJSON.string(session.user.id.uuidString),
            "body": AnyJSON.string(body),
        ]

        try await client
            .from("community_comments")
            .insert(payload)
            .execute()
    }

    func deleteComment(id: UUID) async throws {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard let session = try? await client.auth.session else {
            throw CommunityServiceError.notAuthenticated
        }

        let payload: JSONObject = [
            "deleted_at": AnyJSON.string(Date().ISO8601Format()),
            "deleted_by": AnyJSON.string(session.user.id.uuidString),
        ]

        try await client
            .from("community_comments")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Empty response helper
private struct EmptyResponse: Codable {
    // swiftlint:disable:next type_name
    let unused: String?

    enum CodingKeys: String, CodingKey {
        case unused = "post_id"
    }
}
