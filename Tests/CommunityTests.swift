import XCTest
@testable import Ruhsatim

// MARK: - Community Tests
// Topluluk özelliği için birim testler.

// MARK: - Post Validation

final class CommunityPostValidationTests: XCTestCase {
    func testValidPost() {
        let errors = CommunityPost.validate(
            title: "Renault Clio bakım tecrübem",
            body: "Geçen hafta 60.000 km bakımını yaptırdım. Parça ve işçilik maliyetlerini paylaşıyorum.",
            postType: .experience,
            tags: ["Bakım", "Masraf"]
        )
        XCTAssertTrue(errors.isValid)
        XCTAssertTrue(errors.allErrors.isEmpty)
    }

    func testEmptyTitleReturnsError() {
        let errors = CommunityPost.validate(
            title: "",
            body: "Geçen hafta 60.000 km bakımını yaptırdım. Parça ve işçilik maliyetleri.",
            postType: .experience,
            tags: ["Bakım"]
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.title)
    }

    func testShortTitleReturnsError() {
        let errors = CommunityPost.validate(
            title: "abc",
            body: "Geçen hafta 60.000 km bakımını yaptırdım. Parça ve işçilik maliyetleri.",
            postType: .experience,
            tags: ["Bakım"]
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.title)
    }

    func testEmptyBodyReturnsError() {
        let errors = CommunityPost.validate(
            title: "Renault Clio bakım tecrübem",
            body: "",
            postType: .experience,
            tags: ["Bakım"]
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.body)
    }

    func testShortBodyReturnsError() {
        let errors = CommunityPost.validate(
            title: "Renault Clio bakım",
            body: "Kısa metin",
            postType: .experience,
            tags: ["Bakım"]
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.body)
    }

    func testMissingPostTypeReturnsError() {
        let errors = CommunityPost.validate(
            title: "Renault Clio bakım tecrübem",
            body: "Geçen hafta 60.000 km bakımını yaptırdım.",
            postType: nil,
            tags: ["Bakım"]
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.postType)
    }

    func testMissingTagsReturnsError() {
        let errors = CommunityPost.validate(
            title: "Renault Clio bakım tecrübem",
            body: "Geçen hafta 60.000 km bakımını yaptırdım.",
            postType: .experience,
            tags: []
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.tags)
    }

    func testMaxLengthTitle() {
        let longTitle = String(repeating: "a", count: 120)
        let errors = CommunityPost.validate(
            title: longTitle,
            body: "Geçen hafta 60.000 km bakımını yaptırdım. Parça ve işçilik maliyetleri.",
            postType: .experience,
            tags: ["Bakım"]
        )
        XCTAssertTrue(errors.isValid)
    }

    func testTitleOneOverMaxFails() {
        let tooLongTitle = String(repeating: "a", count: 121)
        let errors = CommunityPost.validate(
            title: tooLongTitle,
            body: "Geçen hafta 60.000 km bakımını yaptırdım. Parça ve işçilik maliyetleri.",
            postType: .experience,
            tags: ["Bakım"]
        )
        XCTAssertFalse(errors.isValid)
        XCTAssertNotNil(errors.title)
    }
}

// MARK: - Profile Validation

final class CommunityProfileValidationTests: XCTestCase {
    func testValidUsername() {
        XCTAssertNil(CommunityProfile.validateUsername("fatih_test"))
    }

    func testTooShortUsername() {
        let error = CommunityProfile.validateUsername("ab")
        XCTAssertNotNil(error)
    }

    func testTooLongUsername() {
        let long = String(repeating: "a", count: 21)
        let error = CommunityProfile.validateUsername(long)
        XCTAssertNotNil(error)
    }

    func testUsernameWithSpecialChars() {
        let error = CommunityProfile.validateUsername("fatih test")
        XCTAssertNotNil(error)
    }

    func testUsernameWithTurkishChars() {
        let error = CommunityProfile.validateUsername("fatihışüğ")
        XCTAssertNotNil(error)
    }

    func testUsernameUnderscoreOk() {
        XCTAssertNil(CommunityProfile.validateUsername("fatih_test_123"))
    }

    func testEmptyDisplayNameOk() {
        XCTAssertNil(CommunityProfile.validateDisplayName(nil))
        XCTAssertNil(CommunityProfile.validateDisplayName(""))
    }

    func testLongDisplayNameFails() {
        let long = String(repeating: "a", count: 51)
        XCTAssertNotNil(CommunityProfile.validateDisplayName(long))
    }
}

// MARK: - Role Permissions

final class CommunityRolePermissionTests: XCTestCase {
    private func makeProfile(role: CommunityRole, isBanned: Bool = false, isPro: Bool = false) -> CommunityProfile {
        CommunityProfile(
            id: UUID(),
            username: "test",
            displayName: nil,
            avatarURL: nil,
            role: role,
            isVerified: role == .admin,
            isBanned: isBanned,
            isPro: isPro,
            defaultVehicleBrand: nil,
            defaultVehicleModel: nil,
            defaultVehicleYear: nil,
            showVehicleOnPosts: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testAdminIsModerator() {
        let admin = makeProfile(role: .admin)
        XCTAssertTrue(admin.isModerator)
    }

    func testModeratorIsModerator() {
        let mod = makeProfile(role: .moderator)
        XCTAssertTrue(mod.isModerator)
    }

    func testUserIsNotModerator() {
        let user = makeProfile(role: .user)
        XCTAssertFalse(user.isModerator)
    }

    func testBannedUserCannotCreateContent() {
        let banned = makeProfile(role: .user, isBanned: true)
        XCTAssertFalse(banned.canCreateContent)
    }

    func testNormalUserCanCreateContent() {
        let user = makeProfile(role: .user, isBanned: false)
        XCTAssertTrue(user.canCreateContent)
    }
}

// MARK: - Auth Gate (forum writing is auth-gated, not Pro-gated)

final class CommunityAuthGateTests: XCTestCase {
    // Forum yazma artık Pro gerektirmez — auth yeterlidir.
    // canCreateCommunityPost() ve canWriteComment() kaldırıldı.
    // Guest auth kontrolü CommunityAuthService üzerinden yapılır.
    // Bu testler auth-gate modelinin doğru çalıştığını doğrular.

    func testOnlyMultipleVehiclesRemainProGatedForMVP() {
        let free = PaywallService(isProForTesting: false)
        // Tek araç MVP özellikleri free olmalı
        XCTAssertTrue(free.canCreateSaleFile())
        XCTAssertTrue(free.canAccessAdvancedReports())
        XCTAssertTrue(free.canCreateInspectionReport())
        XCTAssertTrue(free.canAddDocument(currentCount: 5))
        XCTAssertTrue(free.canAddDocument(currentCount: 500))
        // Pro gate yalnızca ikinci ve sonraki araçlarda kalır
        XCTAssertFalse(free.canAddVehicle(currentCount: 1))

        let pro = PaywallService(isProForTesting: true)
        XCTAssertTrue(pro.canCreateSaleFile())
        XCTAssertTrue(pro.canAccessAdvancedReports())
        XCTAssertTrue(pro.canCreateInspectionReport())
        XCTAssertTrue(pro.canAddVehicle(currentCount: 99))
        XCTAssertTrue(pro.canAddDocument(currentCount: 500))
    }
}

// MARK: - Report Reason Mapping

final class CommunityReportReasonMappingTests: XCTestCase {
    func testAllReasonsHaveDisplayNames() {
        for reason in ReportReason.allCases {
            XCTAssertFalse(reason.displayName.isEmpty, "\(reason) has no display name")
        }
    }

    func testAllReasonsHaveSFSymbols() {
        for reason in ReportReason.allCases {
            XCTAssertFalse(reason.sfSymbol.isEmpty, "\(reason) has no SF Symbol")
        }
    }

    func testReportReasonRawValuesAreStable() {
        // Raw values must match Supabase CHECK constraint
        XCTAssertEqual(ReportReason.spam.rawValue, "spam")
        XCTAssertEqual(ReportReason.harassment.rawValue, "harassment")
        XCTAssertEqual(ReportReason.misleading.rawValue, "misleading")
        XCTAssertEqual(ReportReason.personalInfo.rawValue, "personal_info")
        XCTAssertEqual(ReportReason.inappropriate.rawValue, "inappropriate")
        XCTAssertEqual(ReportReason.other.rawValue, "other")
    }
}

// MARK: - Vehicle Label Formatting

final class CommunityVehicleLabelTests: XCTestCase {
    private func makeProfile(brand: String?, model: String?, year: Int?, show: Bool) -> CommunityProfile {
        CommunityProfile(
            id: UUID(),
            username: "test",
            displayName: nil,
            avatarURL: nil,
            role: .user,
            isVerified: false,
            isBanned: false,
            isPro: false,
            defaultVehicleBrand: brand,
            defaultVehicleModel: model,
            defaultVehicleYear: year,
            showVehicleOnPosts: show,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testVehicleLabelWithFullData() {
        let profile = makeProfile(brand: "Renault", model: "Clio", year: 2020, show: true)
        XCTAssertEqual(profile.vehicleLabel, "Renault Clio 2020")
    }

    func testVehicleLabelWithBrandOnly() {
        let profile = makeProfile(brand: "Renault", model: nil, year: nil, show: true)
        XCTAssertEqual(profile.vehicleLabel, "Renault")
    }

    func testVehicleLabelEmptyWhenNotShown() {
        let profile = makeProfile(brand: "Renault", model: "Clio", year: 2020, show: false)
        XCTAssertNil(profile.vehicleLabel)
    }

    func testVehicleLabelWithoutYear() {
        let profile = makeProfile(brand: "BMW", model: "320i", year: nil, show: true)
        XCTAssertEqual(profile.vehicleLabel, "BMW 320i")
    }

    func testVehicleLabelEmptyWithNoBrand() {
        let profile = makeProfile(brand: nil, model: "Clio", year: 2020, show: true)
        XCTAssertNil(profile.vehicleLabel)
    }

    func testVehicleLabelNeverContainsPlate() {
        // Vehicle label should only contain brand/model/year — never plate
        let profile = makeProfile(brand: "Renault", model: "Clio", year: 2020, show: true)
        let label = profile.vehicleLabel ?? ""
        // Plate format: "34 ABC 123" — numbers+letters format
        let platePattern = try? NSRegularExpression(pattern: "\\d{2}\\s?[A-Z]{1,3}\\s?\\d{2,4}")
        let range = NSRange(label.startIndex..., in: label)
        let match = platePattern?.firstMatch(in: label, options: [], range: range)
        XCTAssertNil(match, "Vehicle label should never contain plate format")
    }
}

// MARK: - Post Type Enum

final class CommunityPostTypeTests: XCTestCase {
    func testAllPostTypesHaveDisplayNames() {
        for type in PostType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) has no display name")
        }
    }

    func testAllPostTypesHaveSFSymbols() {
        for type in PostType.allCases {
            XCTAssertFalse(type.sfSymbol.isEmpty, "\(type) has no SF Symbol")
        }
    }

    func testPostTypeRawValuesMatchSupabaseCheck() {
        XCTAssertEqual(PostType.news.rawValue, "news")
        XCTAssertEqual(PostType.announcement.rawValue, "announcement")
        XCTAssertEqual(PostType.advice.rawValue, "advice")
        XCTAssertEqual(PostType.problem.rawValue, "problem")
        XCTAssertEqual(PostType.experience.rawValue, "experience")
        XCTAssertEqual(PostType.question.rawValue, "question")
    }
}

// MARK: - Community Role Enum

final class CommunityRoleTests: XCTestCase {
    func testAllRolesHaveDisplayNames() {
        for role in CommunityRole.allCases {
            XCTAssertFalse(role.displayName.isEmpty, "\(role) has no display name")
        }
    }

    func testRoleRawValuesMatchSupabaseCheck() {
        XCTAssertEqual(CommunityRole.user.rawValue, "user")
        XCTAssertEqual(CommunityRole.moderator.rawValue, "moderator")
        XCTAssertEqual(CommunityRole.admin.rawValue, "admin")
    }
}

// MARK: - Moderation Action Type Differentiation

final class CommunityModerationActionTests: XCTestCase {
    private func makeReport(targetType: String, reason: ReportReason = .spam) -> CommunityReport {
        CommunityReport(
            id: UUID(),
            reporterId: UUID(),
            targetType: targetType,
            targetId: UUID(),
            reason: reason,
            status: .pending,
            createdAt: Date()
        )
    }

    func testTargetLabelForPost() {
        let report = makeReport(targetType: "post")
        XCTAssertEqual(report.targetLabel, "Gönderi")
    }

    func testTargetLabelForComment() {
        let report = makeReport(targetType: "comment")
        XCTAssertEqual(report.targetLabel, "Yorum")
    }

    func testTargetLabelForUnknownDefaultsToRaw() {
        let report = makeReport(targetType: "unknown_type")
        XCTAssertEqual(report.targetLabel, "unknown_type")
    }

    func testPostReportTargetTypeIsPost() {
        let report = makeReport(targetType: "post")
        XCTAssertEqual(report.targetType, "post")
        XCTAssertTrue(report.targetType == "post")
        XCTAssertFalse(report.targetType == "comment")
    }

    func testCommentReportTargetTypeIsComment() {
        let report = makeReport(targetType: "comment")
        XCTAssertEqual(report.targetType, "comment")
        XCTAssertTrue(report.targetType == "comment")
        XCTAssertFalse(report.targetType == "post")
    }

    func testReviewStatusTransitions() {
        let report = makeReport(targetType: "post")
        XCTAssertEqual(report.status, .pending)
        XCTAssertTrue(report.isPending)
        XCTAssertFalse(report.isReviewed)
        XCTAssertFalse(report.isDismissed)
    }

    func testReportIdentifiableConformance() {
        let id = UUID()
        let report = CommunityReport(
            id: id,
            reporterId: UUID(),
            targetType: "post",
            targetId: UUID(),
            reason: .harassment,
            status: .pending,
            createdAt: Date()
        )
        XCTAssertEqual(report.id, id)
    }
}
