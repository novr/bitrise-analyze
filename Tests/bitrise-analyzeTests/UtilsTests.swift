import XCTest
@testable import bitrise_analyze

class UtilsTests: XCTestCase {
    
    // MARK: - StatisticsUtils Tests
    
    func testCalculateMedian() {
        let values: [TimeInterval] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let median = calculateMedian(values)
        XCTAssertEqual(median, 3.0)
        
        let evenValues: [TimeInterval] = [1.0, 2.0, 3.0, 4.0]
        let evenMedian = calculateMedian(evenValues)
        XCTAssertEqual(evenMedian, 2.5)
        
        let emptyValues: [TimeInterval] = []
        let emptyMedian = calculateMedian(emptyValues)
        XCTAssertEqual(emptyMedian, 0.0)
    }
    
    func testCalculatePercentile() {
        let values: [TimeInterval] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let sortedValues = values.sorted()
        
        let p50 = calculatePercentile(sortedValues, 50)
        XCTAssertEqual(p50, 5.0)
        
        let p90 = calculatePercentile(sortedValues, 90)
        XCTAssertEqual(p90, 9.0)
        
        let p99 = calculatePercentile(sortedValues, 99)
        XCTAssertEqual(p99, 10.0)
    }
    
    func testCalculateStandardDeviation() {
        let values: [TimeInterval] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let mean: TimeInterval = 3.0
        let stdDev = calculateStandardDeviation(values, mean: mean)
        
        XCTAssertGreaterThan(stdDev, 0.0)
        XCTAssertLessThan(stdDev, 2.0)
    }
    
    func testFormatDuration() {
        let duration1: TimeInterval = 3661.0 // 1時間1分1秒
        let formatted1 = formatDuration(duration1)
        XCTAssertEqual(formatted1, "1h 1m 1s")
        
        let duration2: TimeInterval = 125.0 // 2分5秒
        let formatted2 = formatDuration(duration2)
        XCTAssertEqual(formatted2, "2m 5s")
        
        let duration3: TimeInterval = 45.0 // 45秒
        let formatted3 = formatDuration(duration3)
        XCTAssertEqual(formatted3, "45s")
    }
    
    // MARK: - CSVUtils Tests
    
    func testGenerateSummaryCSV() {
        let stats: [String: BuildStatistics] = [
            "7日": createMockBuildStatistics(period: "7日", totalBuilds: 100)
        ]
        
        let csv = generateSummaryCSV(stats: stats)
        
        XCTAssertTrue(csv.contains("期間,総ビルド数"))
        XCTAssertTrue(csv.contains("7日,100"))
    }
    
    func testGenerateWorkflowCSV() {
        let builds = createMockBuilds()
        let csv = generateWorkflowCSV(builds: builds)
        
        XCTAssertTrue(csv.contains("ワークフロー,実行回数"))
        XCTAssertTrue(csv.contains("test-workflow"))
    }
    
    func testGenerateDailyTrendCSV() {
        let builds = createMockBuilds()
        let csv = generateDailyTrendCSV(builds: builds)
        
        XCTAssertTrue(csv.contains("日付,ビルド数"))
        XCTAssertTrue(csv.contains("2025-10-23"))
    }
    
    func testGenerateHourlyDistributionCSV() {
        let builds = createMockBuilds()
        let csv = generateHourlyDistributionCSV(builds: builds)
        
        XCTAssertTrue(csv.contains("時間,ビルド数"))
        XCTAssertTrue(csv.contains("09:00"))
    }
    
    func testGenerateMachineTypeCSV() {
        let builds = createMockBuilds()
        let csv = generateMachineTypeCSV(builds: builds)
        
        XCTAssertTrue(csv.contains("マシンタイプ,使用回数"))
        XCTAssertTrue(csv.contains("g2-m1.4core"))
    }
    
    func testEscapeCSV() {
        let normalValue = "normal_value"
        let escapedNormal = escapeCSV(normalValue)
        XCTAssertEqual(escapedNormal, "normal_value")
        
        let commaValue = "value,with,comma"
        let escapedComma = escapeCSV(commaValue)
        XCTAssertTrue(escapedComma.hasPrefix("\""))
        XCTAssertTrue(escapedComma.hasSuffix("\""))
        
        let quoteValue = "value\"with\"quote"
        let escapedQuote = escapeCSV(quoteValue)
        XCTAssertTrue(escapedQuote.contains("\"\""))
    }
    
    // MARK: - DateUtils Tests
    
    func testFilterBuildsByPeriod() throws {
        let builds = createMockBuilds()
        let period = AnalysisPeriod(name: "7日", days: 7)
        
        let filteredBuilds = try filterBuildsByPeriod(builds, period: period)
        
        XCTAssertEqual(filteredBuilds.count, builds.count) // すべてのビルドが7日以内
    }
    
    func testFilterBuildsByPeriodAllTime() throws {
        let builds = createMockBuilds()
        let period = AnalysisPeriod(name: "全期間", days: nil)
        
        let filteredBuilds = try filterBuildsByPeriod(builds, period: period)
        
        XCTAssertEqual(filteredBuilds.count, builds.count)
    }
    
    func testCalculateBuildDuration() {
        let build = createMockBuildData()
        let duration = calculateBuildDuration(build)
        
        XCTAssertNotNil(duration)
        XCTAssertGreaterThan(duration!, 0)
    }
    
    func testParseDate() {
        let dateString = "2025-10-23T09:32:32Z"
        let date = parseDate(dateString)
        
        XCTAssertNotNil(date)
    }
    
    func testFormatDate() {
        let date = Date()
        let formatted = formatDate(date, format: "yyyy-MM-dd")
        
        XCTAssertTrue(formatted.contains("2025"))
    }
    
    func testGetHourFromDate() {
        let date = Date()
        let hour = getHourFromDate(date)
        
        XCTAssertGreaterThanOrEqual(hour, 0)
        XCTAssertLessThanOrEqual(hour, 23)
    }
    
    // MARK: - FileUtils Tests
    
    func testFileExists() {
        let existingFile = "/System/Library/CoreServices/SystemVersion.plist"
        let nonExistingFile = "/nonexistent/file.txt"
        
        XCTAssertTrue(fileExists(at: existingFile))
        XCTAssertFalse(fileExists(at: nonExistingFile))
    }
    
    func testGetFileSize() {
        let existingFile = "/System/Library/CoreServices/SystemVersion.plist"
        let fileSize = getFileSize(at: existingFile)
        
        XCTAssertNotNil(fileSize)
        XCTAssertGreaterThan(fileSize!, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockBuildStatistics(period: String, totalBuilds: Int) -> BuildStatistics {
        return BuildStatistics(
            period: period,
            totalBuilds: totalBuilds,
            successCount: 80,
            errorCount: 15,
            abortedCount: 5,
            successRate: 80.0,
            averageDuration: 300.0,
            medianDuration: 250.0,
            minDuration: 100.0,
            maxDuration: 600.0,
            p50Duration: 250.0,
            p75Duration: 350.0,
            p90Duration: 450.0,
            p95Duration: 500.0,
            p99Duration: 550.0,
            standardDeviation: 50.0,
            totalCreditCost: 1000,
            averageCreditCost: 10.0
        )
    }
    
    private func createMockBuilds() -> [BuildData] {
        return [
            createMockBuildData(),
            createMockBuildData(
                triggeredAt: "2025-10-22T10:00:00Z",
                finishedAt: "2025-10-22T10:15:00Z",
                statusText: "error"
            )
        ]
    }
    
    private func createMockBuildData(
        triggeredAt: String = "2025-10-23T09:32:32Z",
        finishedAt: String? = "2025-10-23T09:45:49Z",
        statusText: String = "success"
    ) -> BuildData {
        return BuildData(
            branch: "main",
            buildNumber: 1,
            commitHash: "abc123",
            commitMessage: "Test commit",
            commitViewUrl: "https://example.com",
            creditCost: 0,
            environmentPrepareFinishedAt: "2025-10-23T09:32:34Z",
            finishedAt: finishedAt,
            isOnHold: false,
            isProcessed: true,
            machineTypeId: "g2-m1.4core",
            pullRequestId: nil,
            pullRequestTargetBranch: nil,
            pullRequestViewUrl: nil,
            repository: Repository(
                isDisabled: false,
                isGithubChecksEnabled: false,
                isPublic: false,
                owner: Owner(
                    accountType: "user",
                    name: "testuser",
                    slug: "testuser"
                ),
                projectType: "ios",
                provider: "github",
                repoOwner: "testuser",
                repoSlug: "test-repo",
                repoUrl: "https://github.com/testuser/test-repo",
                slug: "test-slug",
                status: 1,
                title: "test-repo"
            ),
            slug: "test-slug",
            stackIdentifier: "osx-xcode-16.2.x",
            startedOnWorkerAt: "2025-10-23T09:32:35Z",
            status: 1,
            statusText: statusText,
            triggeredAt: triggeredAt,
            triggeredBy: "test-user",
            triggeredWorkflow: "test-workflow"
        )
    }
}
