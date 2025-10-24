import XCTest
@testable import bitrise_analyze

class ModelsTests: XCTestCase {
    
    // MARK: - BuildData Tests
    
    func testBuildDataInitialization() {
        let buildData = createMockBuildData()
        
        XCTAssertEqual(buildData.branch, "main")
        XCTAssertEqual(buildData.buildNumber, 1)
        XCTAssertEqual(buildData.statusText, "success")
        XCTAssertEqual(buildData.creditCost, 0)
        XCTAssertNotNil(buildData.repository)
    }
    
    func testBuildDataCoding() throws {
        let buildData = createMockBuildData()
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(buildData)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedBuildData = try decoder.decode(BuildData.self, from: data)
        
        XCTAssertEqual(buildData.branch, decodedBuildData.branch)
        XCTAssertEqual(buildData.buildNumber, decodedBuildData.buildNumber)
        XCTAssertEqual(buildData.statusText, decodedBuildData.statusText)
    }
    
    // MARK: - Repository Tests
    
    func testRepositoryInitialization() {
        let repository = createMockRepository()
        
        XCTAssertEqual(repository.title, "test-repo")
        XCTAssertEqual(repository.projectType, "ios")
        XCTAssertEqual(repository.provider, "github")
        XCTAssertNotNil(repository.owner)
    }
    
    func testRepositoryCoding() throws {
        let repository = createMockRepository()
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(repository)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedRepository = try decoder.decode(Repository.self, from: data)
        
        XCTAssertEqual(repository.title, decodedRepository.title)
        XCTAssertEqual(repository.projectType, decodedRepository.projectType)
    }
    
    // MARK: - BuildStatistics Tests
    
    func testBuildStatisticsInitialization() {
        let stats = BuildStatistics(
            period: "7日",
            totalBuilds: 100,
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
        
        XCTAssertEqual(stats.period, "7日")
        XCTAssertEqual(stats.totalBuilds, 100)
        XCTAssertEqual(stats.successCount, 80)
        XCTAssertEqual(stats.successRate, 80.0)
        XCTAssertEqual(stats.averageDuration, 300.0)
    }
    
    // MARK: - AnalysisConfiguration Tests
    
    func testAnalysisConfigurationDefault() {
        let config = AnalysisConfiguration.default
        
        XCTAssertEqual(config.periods.count, 4)
        XCTAssertEqual(config.outputFormats.count, 2)
        XCTAssertTrue(config.outputFormats.contains(.csv))
        XCTAssertTrue(config.outputFormats.contains(.markdown))
    }
    
    func testAnalysisConfigurationCoding() throws {
        let config = AnalysisConfiguration.default
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(AnalysisConfiguration.self, from: data)
        
        XCTAssertEqual(config.periods.count, decodedConfig.periods.count)
        XCTAssertEqual(config.outputFormats.count, decodedConfig.outputFormats.count)
    }
    
    // MARK: - Error Models Tests
    
    func testAnalysisErrorDescriptions() {
        let invalidDataError = AnalysisError.invalidData("テストエラー")
        XCTAssertEqual(invalidDataError.localizedDescription, "無効なデータ: テストエラー")
        
        let calculationError = AnalysisError.calculationFailed("計算エラー")
        XCTAssertEqual(calculationError.localizedDescription, "計算エラー: 計算エラー")
        
        let outputError = AnalysisError.outputFailed("出力エラー")
        XCTAssertEqual(outputError.localizedDescription, "出力エラー: 出力エラー")
    }
    
    func testBitriseClientErrorDescriptions() {
        let invalidTokenError = BitriseClientError.invalidToken
        XCTAssertEqual(invalidTokenError.localizedDescription, "無効なアクセストークンです。トークンを確認してください。")
        
        let networkError = BitriseClientError.networkError("ネットワークエラー")
        XCTAssertEqual(networkError.localizedDescription, "ネットワークエラー: ネットワークエラー")
        
        let rateLimitedError = BitriseClientError.rateLimited
        XCTAssertEqual(rateLimitedError.localizedDescription, "APIレート制限に達しました。しばらく待ってから再試行してください。")
    }
    
    // MARK: - Helper Methods
    
    private func createMockBuildData() -> BuildData {
        return BuildData(
            branch: "main",
            buildNumber: 1,
            commitHash: "abc123",
            commitMessage: "Test commit",
            commitViewUrl: "https://example.com",
            creditCost: 0,
            environmentPrepareFinishedAt: "2025-10-23T09:32:34Z",
            finishedAt: "2025-10-23T09:45:49Z",
            isOnHold: false,
            isProcessed: true,
            machineTypeId: "g2-m1.4core",
            pullRequestId: nil,
            pullRequestTargetBranch: nil,
            pullRequestViewUrl: nil,
            repository: createMockRepository(),
            slug: "test-slug",
            stackIdentifier: "osx-xcode-16.2.x",
            startedOnWorkerAt: "2025-10-23T09:32:35Z",
            status: 1,
            statusText: "success",
            triggeredAt: "2025-10-23T09:32:32Z",
            triggeredBy: "test-user",
            triggeredWorkflow: "test-workflow"
        )
    }
    
    private func createMockRepository() -> Repository {
        return Repository(
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
        )
    }
}
