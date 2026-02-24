import XCTest
@testable import bitrise_analyze

final class CostEstimatorTests: XCTestCase {

    // MARK: - isIOSRepo

    func testIsIOSRepoSuffix() {
        XCTAssertTrue(CostEstimator.isIOSRepo("myapp-ios"))
        XCTAssertTrue(CostEstimator.isIOSRepo("myapp_ios"))
        XCTAssertTrue(CostEstimator.isIOSRepo("MyApp-IOS"))
    }

    func testIsIOSRepoPrefix() {
        XCTAssertTrue(CostEstimator.isIOSRepo("ios"))
        XCTAssertTrue(CostEstimator.isIOSRepo("ios-app"))
        XCTAssertTrue(CostEstimator.isIOSRepo("ios_app"))
    }

    func testIsIOSRepoContains() {
        XCTAssertTrue(CostEstimator.isIOSRepo("my-ios-app"))
        XCTAssertTrue(CostEstimator.isIOSRepo("something_ios_here"))
    }

    func testIsIOSRepoFalse() {
        XCTAssertFalse(CostEstimator.isIOSRepo("vision"))
        XCTAssertFalse(CostEstimator.isIOSRepo("curious"))
        XCTAssertFalse(CostEstimator.isIOSRepo("android"))
        XCTAssertFalse(CostEstimator.isIOSRepo("myapp"))
    }

    // MARK: - isAndroidRepo

    func testIsAndroidRepoSuffix() {
        XCTAssertTrue(CostEstimator.isAndroidRepo("myapp-android"))
        XCTAssertTrue(CostEstimator.isAndroidRepo("myapp_android"))
    }

    func testIsAndroidRepoPrefix() {
        XCTAssertTrue(CostEstimator.isAndroidRepo("android"))
        XCTAssertTrue(CostEstimator.isAndroidRepo("android-app"))
    }

    func testIsAndroidRepoFalse() {
        XCTAssertFalse(CostEstimator.isAndroidRepo("myapp"))
        XCTAssertFalse(CostEstimator.isAndroidRepo("ios-app"))
    }

    // MARK: - getXcodePlan

    func testGetXcodePlanZeroHours() {
        let plan = CostEstimator.getXcodePlan(hours: 0)
        XCTAssertEqual(plan.name, "ADP付属")
        XCTAssertEqual(plan.cost, 0)
    }

    func testGetXcodePlanTier1() {
        let plan = CostEstimator.getXcodePlan(hours: 50)
        XCTAssertEqual(plan.name, "tier1")
        XCTAssertEqual(plan.cost, 49.99)
    }

    func testGetXcodePlanTier2() {
        let plan = CostEstimator.getXcodePlan(hours: 101)
        XCTAssertEqual(plan.name, "tier2")
    }

    func testGetXcodePlanTier4() {
        let plan = CostEstimator.getXcodePlan(hours: 5000)
        XCTAssertEqual(plan.name, "tier4")
    }

    // MARK: - getBitrisePlan

    func testGetBitrisePlanUnder100() {
        let plan = CostEstimator.getBitrisePlan(totalBuilds: 50, hasIOS: true, hasAndroid: false)
        XCTAssertEqual(plan.name, "Starter tier1")
    }

    func testGetBitrisePlanIOSAndAndroid() {
        let plan = CostEstimator.getBitrisePlan(totalBuilds: 50, hasIOS: true, hasAndroid: true)
        XCTAssertEqual(plan.name, "Starter tier2")
    }

    func testGetBitrisePlanOver100() {
        let plan = CostEstimator.getBitrisePlan(totalBuilds: 101, hasIOS: true, hasAndroid: true)
        XCTAssertEqual(plan.name, "Pro")
    }

    // MARK: - calculateGitHubActionsCost

    func testCalculateGitHubActionsCost() {
        let cost = CostEstimator.calculateGitHubActionsCost(iosMinutes: 60, androidMinutes: 60, useArm64: false)
        XCTAssertEqual(cost, 60 * 0.08 + 60 * 0.008, accuracy: 0.01)
    }

    // MARK: - calculateCaseCosts

    func testCalculateCaseCostsIOSOnly() {
        let c = CostEstimator.calculateCaseCosts(
            iosHours: 10, androidHours: 0,
            iosBuilds: 50, androidBuilds: 0,
            otherHours: 0, otherBuilds: 0,
            hasIOS: true, hasAndroid: false
        )
        XCTAssertEqual(c.case1XcodePlanName, "ADP付属")
        XCTAssertEqual(c.case3BitrisePlanName, "Starter tier1")
    }

    func testCalculateCaseCostsAndroidOnly() {
        let c = CostEstimator.calculateCaseCosts(
            iosHours: 0, androidHours: 5,
            iosBuilds: 0, androidBuilds: 30,
            otherHours: 0, otherBuilds: 0,
            hasIOS: false, hasAndroid: true
        )
        XCTAssertEqual(c.case1BitrisePlanName, "Starter tier1")
    }
}
