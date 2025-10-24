import XCTest
@testable import bitrise_analyze

class AnalysisModuleTests: XCTestCase {
    
    // MARK: - DataProcessor Tests
    
    func testDataProcessorInitialization() {
        let processor = DataProcessorImpl()
        XCTAssertNotNil(processor)
    }
    
    func testDataProcessorWithCustomConfiguration() {
        let customConfig = AnalysisConfiguration.default
        let processor = DataProcessorImpl(config: customConfig)
        XCTAssertNotNil(processor)
    }
    
    func testDataProcessorProcessBuilds() throws {
        let processor = DataProcessorImpl()
        let builds = createMockBuilds()
        
        let processedData = try processor.processBuilds(builds)
        
        XCTAssertEqual(processedData.builds.count, builds.count)
        XCTAssertFalse(processedData.statistics.isEmpty)
        XCTAssertNotNil(processedData.workflowAnalysis)
        XCTAssertNotNil(processedData.repositoryAnalysis)
    }
    
    // MARK: - DataValidation Tests
    
    func testBuildDataValidatorInitialization() {
        let validator = BuildDataValidator()
        XCTAssertNotNil(validator)
    }
    
    func testBuildDataValidatorWithCustomConfiguration() {
        let customConfig = AnalysisConfiguration.default
        let validator = BuildDataValidator(config: customConfig)
        XCTAssertNotNil(validator)
    }
    
    func testBuildDataValidatorValidateValidData() throws {
        let validator = BuildDataValidator()
        let builds = createMockBuilds()
        
        let validatedBuilds = try validator.validate(builds)
        
        XCTAssertEqual(validatedBuilds.count, builds.count)
    }
    
    func testBuildDataValidatorValidateInvalidData() {
        let validator = BuildDataValidator()
        let invalidBuilds = createInvalidBuilds()
        
        XCTAssertThrowsError(try validator.validate(invalidBuilds)) { error in
            XCTAssertTrue(error is AnalysisError)
        }
    }
    
    // MARK: - StatisticsCalculator Tests
    
    func testImprovedStatisticsCalculatorInitialization() {
        let calculator = ImprovedStatisticsCalculator()
        XCTAssertNotNil(calculator)
    }
    
    func testImprovedStatisticsCalculatorWithCustomConfiguration() {
        let customConfig = AnalysisConfiguration.default
        let calculator = ImprovedStatisticsCalculator(config: customConfig)
        XCTAssertNotNil(calculator)
    }
    
    func testStatisticsCalculatorCalculate() throws {
        let calculator = ImprovedStatisticsCalculator()
        let builds = createMockBuilds()
        
        let statistics = try calculator.calculate(for: builds, period: "7日")
        
        XCTAssertEqual(statistics.period, "7日")
        XCTAssertGreaterThan(statistics.totalBuilds, 0)
        XCTAssertGreaterThanOrEqual(statistics.successRate, 0.0)
        XCTAssertLessThanOrEqual(statistics.successRate, 100.0)
    }
    
    func testStatisticsCalculatorCalculateWithEmptyData() {
        let calculator = ImprovedStatisticsCalculator()
        let emptyBuilds: [BuildData] = []
        
        XCTAssertThrowsError(try calculator.calculate(for: emptyBuilds, period: "7日")) { error in
            XCTAssertTrue(error is AnalysisError)
        }
    }
    
    // MARK: - WorkflowAnalyzer Tests
    
    func testWorkflowAnalyzerImplInitialization() {
        let analyzer = WorkflowAnalyzerImpl()
        XCTAssertNotNil(analyzer)
    }
    
    func testWorkflowAnalyzerImplAnalyzeWorkflows() throws {
        let analyzer = WorkflowAnalyzerImpl()
        let builds = createMockBuilds()
        
        let analysis = try analyzer.analyzeWorkflows(for: builds)
        
        XCTAssertFalse(analysis.topWorkflows.isEmpty)
        XCTAssertNotNil(analysis.longRunningWorkflows)
        XCTAssertNotNil(analysis.highFailureWorkflows)
    }
    
    func testWorkflowAnalyzerImplAnalyzeEmptyWorkflows() throws {
        let analyzer = WorkflowAnalyzerImpl()
        let emptyBuilds: [BuildData] = []
        
        let analysis = try analyzer.analyzeWorkflows(for: emptyBuilds)
        
        XCTAssertTrue(analysis.topWorkflows.isEmpty)
        XCTAssertTrue(analysis.longRunningWorkflows.isEmpty)
        XCTAssertTrue(analysis.highFailureWorkflows.isEmpty)
    }
    
    // MARK: - RepositoryAnalyzer Tests
    
    func testRepositoryAnalyzerImplInitialization() {
        let analyzer = RepositoryAnalyzerImpl()
        XCTAssertNotNil(analyzer)
    }
    
    func testRepositoryAnalyzerImplAnalyzeRepositories() throws {
        let analyzer = RepositoryAnalyzerImpl()
        let builds = createMockBuilds()
        let periods = AnalysisConfiguration.default.periods
        
        let analysis = try analyzer.analyzeRepositories(for: builds, periods: periods)
        
        XCTAssertFalse(analysis.repositoryStats.isEmpty)
        XCTAssertNotNil(analysis.repositoryWorkflows)
        XCTAssertNotNil(analysis.repositoryFailures)
    }
    
    // MARK: - Error Handling Tests
    
    func testAnalysisErrorHandling() {
        let errors: [AnalysisError] = [
            .invalidData("テストデータ"),
            .calculationFailed("計算エラー"),
            .outputFailed("出力エラー"),
            .invalidDateCalculation,
            .fileNotFound("ファイルパス"),
            .encodingFailed("エンコーディングエラー")
        ]
        
        for error in errors {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testDataProcessorPerformance() throws {
        let processor = DataProcessorImpl()
        let largeBuilds = createLargeMockBuilds(count: 1000)
        
        measure {
            do {
                _ = try processor.processBuilds(largeBuilds)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testStatisticsCalculatorPerformance() throws {
        let calculator = ImprovedStatisticsCalculator()
        let largeBuilds = createLargeMockBuilds(count: 1000)
        
        measure {
            do {
                _ = try calculator.calculate(for: largeBuilds, period: "7日")
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
            ),
            createMockBuildData(
                triggeredAt: "2025-10-21T14:30:00Z",
                finishedAt: "2025-10-21T14:45:00Z",
                statusText: "success",
                triggeredWorkflow: "deploy-workflow"
            )
        ]
    }
    
    private func createInvalidBuilds() -> [BuildData] {
        return [
            BuildData(
                branch: nil,
                buildNumber: nil,
                commitHash: nil,
                commitMessage: nil,
                commitViewUrl: nil,
                creditCost: nil,
                environmentPrepareFinishedAt: nil,
                finishedAt: nil,
                isOnHold: nil,
                isProcessed: nil,
                machineTypeId: nil,
                pullRequestId: nil,
                pullRequestTargetBranch: nil,
                pullRequestViewUrl: nil,
                repository: nil,
                slug: nil,
                stackIdentifier: nil,
                startedOnWorkerAt: nil,
                status: nil,
                statusText: nil,
                triggeredAt: nil,
                triggeredBy: nil,
                triggeredWorkflow: nil
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
