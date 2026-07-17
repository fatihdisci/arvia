import Foundation
import SwiftData

// MARK: - Usage Profile Service
// VehicleUsageProfile CRUD + çözümleme (resolution) mantığı.
// Çözümleme kuralı: araç bazlı profil > appliesToAllVehicles profili > nil.
final class UsageProfileService {
    static let shared = UsageProfileService()

    init() {}

    // MARK: - Resolution (saf fonksiyon — test edilebilir)
    /// Verilen profiller içinden bir araç için geçerli profili döndürür.
    /// 1) vehicleId eşleşen (appliesToAll olmayan) profil kazanır.
    /// 2) yoksa appliesToAllVehicles=true olan ilk profil.
    /// 3) yoksa nil.
    static func resolve(for vehicleId: UUID, from profiles: [VehicleUsageProfile]) -> VehicleUsageProfile? {
        if let specific = profiles.first(where: { $0.vehicleId == vehicleId && !$0.appliesToAllVehicles }) {
            return specific
        }
        if let global = profiles
            .filter({ $0.appliesToAllVehicles })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            return global
        }
        return nil
    }

    // MARK: - Fetch
    func allProfiles(context: ModelContext) -> [VehicleUsageProfile] {
        (try? context.fetch(FetchDescriptor<VehicleUsageProfile>())) ?? []
    }

    func resolvedProfile(for vehicleId: UUID, context: ModelContext) -> VehicleUsageProfile? {
        Self.resolve(for: vehicleId, from: allProfiles(context: context))
    }

    /// Global (tüm araçlara uygulanan) profil — onboarding ve Ayarlar düzenlemesi için.
    func globalProfile(context: ModelContext) -> VehicleUsageProfile? {
        allProfiles(context: context)
            .filter { $0.appliesToAllVehicles }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first
    }

    // MARK: - Upsert
    /// Global profili oluşturur veya günceller (tek bir global profil tutulur).
    @discardableResult
    func saveGlobalProfile(
        dailyKmBand: DailyKmBand,
        routeType: RouteType,
        fuelConsumptionCity: Double?,
        fuelConsumptionHighway: Double?,
        primaryUser: String?,
        tripTypes: [String],
        context: ModelContext
    ) throws -> VehicleUsageProfile {
        let profile: VehicleUsageProfile
        let profiles = try context.fetch(FetchDescriptor<VehicleUsageProfile>())
        if let existing = profiles
            .filter({ $0.appliesToAllVehicles })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            profile = existing
        } else {
            profile = VehicleUsageProfile(vehicleId: UUID(), appliesToAllVehicles: true)
            context.insert(profile)
        }
        profile.dailyKmBand = dailyKmBand
        profile.routeType = routeType
        profile.fuelConsumptionCity = fuelConsumptionCity
        profile.fuelConsumptionHighway = fuelConsumptionHighway
        profile.primaryUser = primaryUser
        profile.tripTypes = tripTypes
        profile.appliesToAllVehicles = true
        profile.updatedAt = Date()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return profile
    }

    func deleteAll(context: ModelContext) throws {
        for profile in try context.fetch(FetchDescriptor<VehicleUsageProfile>()) {
            context.delete(profile)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
