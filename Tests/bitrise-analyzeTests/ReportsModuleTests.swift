import XCTest
@testable import bitrise_analyze

class ReportsModuleTests: XCTestCase {
    
    // MARK: - AggregateStats Tests
    
    func testAggregateStatsInitialization() {
        let aggregateStats = AggregateStats()
        XCTAssertNotNil(aggregateStats)
    }
    
    func testAggregateStatsConfiguration() {
        let config = AggregateStats.configuration
        XCTAssertEqual(config.commandName, "aggregate")
        XCTAssertEqual(config.abstract, "Bitriseビルドデータの集計とレポート生成")
    }
    
    func testAggregateStatsDefaultValues() {
        // ArgumentParserのテストは複雑なため、設定値のみをテスト
        XCTAssertEqual(AggregateStats.configuration.commandName, "aggregate")
        XCTAssertEqual(AggregateStats.configuration.abstract, "Bitriseビルドデータの集計とレポート生成")
    }
    
    // MARK: - ReportGenerator Tests
    
    func testReportGeneratorImplInitialization() {
        let generator = ReportGeneratorImpl()
        XCTAssertNotNil(generator)
    }
    
    func testReportGeneratorImplWithCustomConfiguration() {
        let customConfig = AnalysisConfiguration.default
        let generator = ReportGeneratorImpl(config: customConfig)
        XCTAssertNotNil(generator)
    }
    
    func testReportGeneratorImplGenerateReports() async throws {
        let generator = ReportGeneratorImpl()
        let processedData = createMockProcessedData()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_reports")
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        try await generator.generateReports(from: processedData, to: outputURL)
        
        // Verify output directory was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }
    
    // MARK: - CSVGenerator Tests
    
    func testImprovedCSVGeneratorInitialization() {
        let generator = ImprovedCSVGenerator()
        XCTAssertNotNil(generator)
    }
    
    func testImprovedCSVGeneratorWithCustomEscaper() {
        let escaper = CSVEscaperImpl()
        let generator = ImprovedCSVGenerator(escaper: escaper)
        XCTAssertNotNil(generator)
    }
    
    func testImprovedCSVGeneratorGenerateCSVFromStatistics() throws {
        let generator = ImprovedCSVGenerator()
        let statistics: [String: BuildStatistics] = [
            "7日": createMockBuildStatistics(period: "7日", totalBuilds: 100)
        ]
        
        let csv = try generator.generateCSV(from: statistics)
        
        XCTAssertTrue(csv.contains("期間,総ビルド数"))
        XCTAssertTrue(csv.contains("7日,100"))
    }
    
    func testImprovedCSVGeneratorGenerateCSVFromRepositoryAnalysis() throws {
        let generator = ImprovedCSVGenerator()
        let analysis = createMockRepositoryAnalysis()
        
        let csv = try generator.generateCSV(from: analysis)
        
        XCTAssertTrue(csv.contains("リポジトリ"))
        XCTAssertTrue(csv.contains("test-repo"))
    }
    
    func testImprovedCSVGeneratorGenerateCSVFromWorkflowAnalysis() throws {
        let generator = ImprovedCSVGenerator()
        let analysis = createMockWorkflowAnalysis()
        
        let csv = try generator.generateCSV(from: analysis)
        
        XCTAssertTrue(csv.contains("ワークフロー"))
        XCTAssertTrue(csv.contains("test-workflow"))
    }
    
    // MARK: - MarkdownGenerator Tests
    
    func testMarkdownGeneratorImplInitialization() {
        let generator = MarkdownGeneratorImpl()
        XCTAssertNotNil(generator)
    }
    
    func testMarkdownGeneratorImplGenerateMarkdown() throws {
        let generator = MarkdownGeneratorImpl()
        let statistics = createMockBuildStatistics(period: "7日", totalBuilds: 100)
        let data = (statistics, "7日")
        
        let markdown = try generator.generateMarkdown(from: data)
        
        XCTAssertTrue(markdown.contains("# Bitrise ビルド統計レポート"))
        XCTAssertTrue(markdown.contains("7日期間"))
        XCTAssertTrue(markdown.contains("総ビルド数"))
        XCTAssertTrue(markdown.contains("100"))
    }
    
    func testMarkdownGeneratorImplGenerateMarkdownWithInvalidData() {
        let generator = MarkdownGeneratorImpl()
        let invalidData = "invalid data"
        
        XCTAssertThrowsError(try generator.generateMarkdown(from: invalidData)) { error in
            XCTAssertTrue(error is AnalysisError)
        }
    }
    
    // MARK: - OutputManager Tests
    
    func testOutputManagerImplInitialization() {
        let manager = OutputManagerImpl()
        XCTAssertNotNil(manager)
    }
    
    func testOutputManagerImplWriteReports() throws {
        let manager = OutputManagerImpl()
        let reports = createMockReports()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output")
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        try manager.writeReports(reports, to: outputURL)
        
        // Verify files were created
        for report in reports {
            let fileURL = outputURL.appendingPathComponent(report.filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
    
    func testOutputManagerImplWriteCSV() throws {
        let manager = OutputManagerImpl()
        let csv = "header1,header2\nvalue1,value2"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output")
        let filename = "test.csv"
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        try manager.writeCSV(csv, filename: filename, to: outputURL)
        
        let fileURL = outputURL.appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(content, csv)
    }
    
    func testOutputManagerImplWriteMarkdown() throws {
        let manager = OutputManagerImpl()
        let markdown = "# Test Report\n\nThis is a test report."
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output")
        let filename = "test.md"
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        try manager.writeMarkdown(markdown, filename: filename, to: outputURL)
        
        let fileURL = outputURL.appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(content, markdown)
    }
    
    // MARK: - Integration Tests
    
    func testFullReportGenerationWorkflow() async throws {
        let generator = ReportGeneratorImpl()
        let processedData = createMockProcessedData()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("integration_test")
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        try await generator.generateReports(from: processedData, to: outputURL)
        
        // Verify all expected files were created
        let expectedFiles = [
            "builds_summary.csv",
            "workflow_stats.csv",
            "daily_trends.csv",
            "hourly_distribution.csv",
            "machine_type_stats.csv",
            "repository_stats.csv",
            "report_7日.md"
        ]
        
        for filename in expectedFiles {
            let fileURL = outputURL.appendingPathComponent(filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "File \(filename) was not created")
        }
    }
    
    // MARK: - Performance Tests
    
    func testReportGenerationPerformance() async throws {
        let generator = ReportGeneratorImpl()
        let largeProcessedData = createLargeMockProcessedData()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("performance_test")
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        measure {
            let expectation = XCTestExpectation(description: "Performance test")
            
            Task {
                do {
                    try await generator.generateReports(from: largeProcessedData, to: outputURL)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockProcessedData() -> ProcessedData {
        let builds = createMockBuilds()
        let statistics: [String: BuildStatistics] = [
            "7日": createMockBuildStatistics(period: "7日", totalBuilds: 100)
        ]
        let workflowAnalysis = createMockWorkflowAnalysis()
        let repositoryAnalysis = createMockRepositoryAnalysis()
        
        return ProcessedData(
            builds: builds,
            statistics: statistics,
            workflowAnalysis: workflowAnalysis,
            repositoryAnalysis: repositoryAnalysis
        )
    }
    
    private func createLargeMockProcessedData() -> ProcessedData {
        let builds = createLargeMockBuilds(count: 1000)
        let statistics: [String: BuildStatistics] = [
            "7日": createMockBuildStatistics(period: "7日", totalBuilds: 1000),
            "30日": createMockBuildStatistics(period: "30日", totalBuilds: 5000)
        ]
        let workflowAnalysis = createMockWorkflowAnalysis()
        let repositoryAnalysis = createMockRepositoryAnalysis()
        
        return ProcessedData(
            builds: builds,
            statistics: statistics,
            workflowAnalysis: workflowAnalysis,
            repositoryAnalysis: repositoryAnalysis
        )
    }
    
    private func createMockBuildStatistics(period: String, totalBuilds: Int) -> BuildStatistics {
        return BuildStatistics(
            period: period,
            totalBuilds: totalBuilds,
            successCount: Int(Double(totalBuilds) * 0.8),
            errorCount: Int(Double(totalBuilds) * 0.15),
            abortedCount: Int(Double(totalBuilds) * 0.05),
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
            totalCreditCost: totalBuilds * 10,
            averageCreditCost: 10.0
        )
    }
    
    private func createMockWorkflowAnalysis() -> WorkflowAnalysis {
        return WorkflowAnalysis(
            topWorkflows: [("test-workflow", 50), ("deploy-workflow", 30)],
            longRunningWorkflows: [("test-workflow", 300.0), ("deploy-workflow", 450.0)],
            highFailureWorkflows: [("failing-workflow", 75.0)]
        )
    }
    
    private func createMockRepositoryAnalysis() -> RepositoryAnalysis {
        let statistics: [String: [String: BuildStatistics]] = [
            "test-repo": ["7日": createMockBuildStatistics(period: "7日", totalBuilds: 100)]
        ]
        let workflows: [String: [String]] = [
            "test-repo": ["test-workflow", "deploy-workflow"]
        ]
        let failures: [String: [String]] = [
            "test-repo": ["failing-workflow"]
        ]
        
        return RepositoryAnalysis(
            repositoryStats: statistics,
            repositoryWorkflows: workflows,
            repositoryFailures: failures
        )
    }
    
    private func createMockReports() -> [Report] {
        return [
            Report(filename: "test1.csv", content: "header1,header2\nvalue1,value2", format: .csv),
            Report(filename: "test2.md", content: "# Test Report\n\nContent", format: .markdown)
        ]
    }
    
    private func createMockBuilds() -> [BuildData] {
        return [
            createMockBuildData(
                triggeredAt: "2025-10-23T09:32:32Z",
                finishedAt: "2025-10-23T09:45:49Z",
                statusText: "success",
                triggeredWorkflow: "test-workflow"
            ),
            createMockBuildData(
                triggeredAt: "2025-10-22T10:00:00Z",
                finishedAt: "2025-10-22T10:15:00Z",
                statusText: "error",
                triggeredWorkflow: "test-workflow"
            )
        ]
    }
    
    private func createLargeMockBuilds(count: Int) -> [BuildData] {
        var builds: [BuildData] = []
        
        for i in 0..<count {
            let build = createMockBuildData(
                triggeredAt: "2025-10-\(20 + (i % 10))T09:32:32Z",
                finishedAt: "2025-10-\(20 + (i % 10))T09:45:49Z",
                statusText: i % 10 == 0 ? "error" : "success",
                triggeredWorkflow: "workflow-\(i % 5)"
            )
            builds.append(build)
        }
        
        return builds
    }
    
    private func createMockBuildData(
        triggeredAt: String,
        finishedAt: String?,
        statusText: String,
        triggeredWorkflow: String
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
            triggeredWorkflow: triggeredWorkflow
        )
    }
}
