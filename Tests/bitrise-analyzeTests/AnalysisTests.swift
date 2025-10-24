import XCTest
@testable import bitrise_analyze

class AnalysisTests: XCTestCase {
    
    // MARK: - テストデータ
    
    private func createMockBuildData(
        triggeredAt: String = "2025-10-23T09:32:32Z",
        finishedAt: String? = "2025-10-23T09:45:49Z",
        statusText: String = "success",
        triggeredWorkflow: String = "test-workflow",
        repositoryTitle: String = "test-repo",
        creditCost: Int = 0
    ) -> BuildData {
        return BuildData(
            branch: "main",
            buildNumber: 1,
            commitHash: "abc123",
            commitMessage: "Test commit",
            commitViewUrl: "https://example.com",
            creditCost: creditCost,
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
                title: repositoryTitle
            ),
            slug: "test-slug",
            stackIdentifier: "osx-xcode-16.2.x",
            startedOnWorkerAt: "2025-10-23T09:32:34Z",
            status: 1,
            statusText: statusText,
            triggeredAt: triggeredAt,
            triggeredBy: "webhook",
            triggeredWorkflow: triggeredWorkflow
        )
    }
    
    // MARK: - 統計計算器のテスト
    
    func testStatisticsCalculation() throws {
        let calculator = ImprovedStatisticsCalculator()
        let builds = [
            createMockBuildData(statusText: "success"),
            createMockBuildData(statusText: "success"),
            createMockBuildData(statusText: "error"),
            createMockBuildData(statusText: "aborted")
        ]
        
        let stats = try calculator.calculate(for: builds, period: "テスト期間")
        
        XCTAssertEqual(stats.totalBuilds, 4)
        XCTAssertEqual(stats.successCount, 2)
        XCTAssertEqual(stats.errorCount, 1)
        XCTAssertEqual(stats.abortedCount, 1)
        XCTAssertEqual(stats.successRate, 50.0, accuracy: 0.1)
    }
    
    func testStatisticsCalculationWithEmptyData() {
        let calculator = ImprovedStatisticsCalculator()
        let builds: [BuildData] = []
        
        XCTAssertThrowsError(try calculator.calculate(for: builds, period: "テスト期間")) { error in
            XCTAssertTrue(error is AnalysisError)
        }
    }
    
    func testStatisticsCalculationWithInvalidData() {
        let calculator = ImprovedStatisticsCalculator()
        let builds = [
            createMockBuildData(triggeredAt: "invalid-date")
        ]
        
        // 無効なデータが半数以上の場合、エラーが発生する
        XCTAssertThrowsError(try calculator.calculate(for: builds, period: "テスト期間"))
    }
    
    // MARK: - データ検証器のテスト
    
    func testDataValidation() throws {
        let validator = BuildDataValidator()
        let builds = [
            createMockBuildData(),
            createMockBuildData(statusText: "error"),
            createMockBuildData(statusText: "aborted")
        ]
        
        let validatedBuilds = try validator.validate(builds)
        XCTAssertEqual(validatedBuilds.count, 3)
    }
    
    func testDataValidationWithInvalidStatus() {
        let validator = BuildDataValidator()
        let builds = [
            createMockBuildData(statusText: "invalid-status")
        ]
        
        XCTAssertThrowsError(try validator.validate(builds)) { error in
            XCTAssertTrue(error is AnalysisError)
        }
    }
    
    func testDataValidationWithInvalidDate() {
        let validator = BuildDataValidator()
        let builds = [
            createMockBuildData(triggeredAt: "invalid-date")
        ]
        
        XCTAssertThrowsError(try validator.validate(builds)) { error in
            XCTAssertTrue(error is AnalysisError)
        }
    }
    
    // MARK: - ワークフロー分析器のテスト
    
    func testWorkflowAnalysis() throws {
        let analyzer = WorkflowAnalyzerImpl()
        let builds = [
            createMockBuildData(statusText: "success", triggeredWorkflow: "workflow1"),
            createMockBuildData(statusText: "success", triggeredWorkflow: "workflow1"),
            createMockBuildData(statusText: "success", triggeredWorkflow: "workflow2"),
            createMockBuildData(statusText: "error", triggeredWorkflow: "workflow3"),
            createMockBuildData(statusText: "error", triggeredWorkflow: "workflow3"),
            createMockBuildData(statusText: "error", triggeredWorkflow: "workflow3")
        ]
        
        let analysis = try analyzer.analyzeWorkflows(for: builds)
        
        XCTAssertEqual(analysis.topWorkflows.count, 3)
        // workflow3が3回実行されているので、実行回数が最も多い
        XCTAssertEqual(analysis.topWorkflows.first?.0, "workflow3")
        XCTAssertEqual(analysis.topWorkflows.first?.1, 3)
    }
    
    // MARK: - リポジトリ分析器のテスト
    
    func testRepositoryAnalysis() throws {
        let analyzer = RepositoryAnalyzerImpl()
        let builds = [
            createMockBuildData(repositoryTitle: "repo1"),
            createMockBuildData(repositoryTitle: "repo1"),
            createMockBuildData(repositoryTitle: "repo2")
        ]
        
        let periods = [
            AnalysisPeriod(name: "テスト期間", days: nil)
        ]
        
        let analysis = try analyzer.analyzeRepositories(for: builds, periods: periods)
        
        XCTAssertEqual(analysis.repositoryStats.count, 2)
        XCTAssertTrue(analysis.repositoryStats.keys.contains("repo1"))
        XCTAssertTrue(analysis.repositoryStats.keys.contains("repo2"))
    }
    
    // MARK: - CSVエスケープのテスト
    
    func testCSVEscaping() {
        let escaper = CSVEscaperImpl()
        
        // 通常の値
        XCTAssertEqual(escaper.escape("normal value"), "normal value")
        
        // カンマを含む値
        XCTAssertEqual(escaper.escape("value,with,comma"), "\"value,with,comma\"")
        
        // ダブルクォートを含む値
        XCTAssertEqual(escaper.escape("value\"with\"quotes"), "\"value\"\"with\"\"quotes\"")
        
        // 改行を含む値
        XCTAssertEqual(escaper.escape("value\nwith\nnewline"), "\"value\nwith\nnewline\"")
    }
    
    // MARK: - パフォーマンステスト
    
    func testPerformanceWithLargeDataset() {
        let calculator = ImprovedStatisticsCalculator()
        
        // 大量のデータを生成
        var builds: [BuildData] = []
        for i in 0..<1000 {
            builds.append(createMockBuildData(
                triggeredAt: "2025-10-23T09:32:32Z",
                finishedAt: "2025-10-23T09:45:49Z",
                triggeredWorkflow: "workflow-\(i % 10)"
            ))
        }
        
        measure {
            do {
                _ = try calculator.calculate(for: builds, period: "パフォーマンステスト")
            } catch {
                XCTFail("パフォーマンステストでエラーが発生: \(error)")
            }
        }
    }
    
    // MARK: - エラーハンドリングのテスト
    
    func testErrorHandling() {
        let calculator = ImprovedStatisticsCalculator()
        
        // 無効なデータでのテスト（半数以上が無効な場合）
        let invalidBuilds = [
            createMockBuildData(triggeredAt: "invalid"),
            createMockBuildData(finishedAt: "invalid")
        ]
        
        XCTAssertThrowsError(try calculator.calculate(for: invalidBuilds, period: "エラーテスト"))
    }
    
    // MARK: - エッジケースのテスト
    
    func testEdgeCases() throws {
        let calculator = ImprovedStatisticsCalculator()
        
        // 実行時間が0のケース
        let zeroDurationBuilds = [
            createMockBuildData(
                triggeredAt: "2025-10-23T09:32:32Z",
                finishedAt: "2025-10-23T09:32:32Z"
            )
        ]
        
        let stats = try calculator.calculate(for: zeroDurationBuilds, period: "エッジケース")
        XCTAssertEqual(stats.minDuration, 0)
        XCTAssertEqual(stats.maxDuration, 0)
    }
    
    func testEmptyWorkflowAnalysis() throws {
        let analyzer = WorkflowAnalyzerImpl()
        let builds: [BuildData] = []
        
        let analysis = try analyzer.analyzeWorkflows(for: builds)
        XCTAssertTrue(analysis.topWorkflows.isEmpty)
        XCTAssertTrue(analysis.longRunningWorkflows.isEmpty)
        XCTAssertTrue(analysis.highFailureWorkflows.isEmpty)
    }
}
