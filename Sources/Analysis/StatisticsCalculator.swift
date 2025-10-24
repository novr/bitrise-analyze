import Foundation

// MARK: - 改善された統計計算器

class ImprovedStatisticsCalculator: StatisticsCalculator {
    private let config: AnalysisConfiguration
    private let dateFormatter: DateFormatterProvider
    private let validator: DataValidator
    
    init(config: AnalysisConfiguration = .default, 
         dateFormatter: DateFormatterProvider = DefaultDateFormatterProvider(),
         validator: DataValidator = BuildDataValidator()) {
        self.config = config
        self.dateFormatter = dateFormatter
        self.validator = validator
    }
    
    func calculate(for builds: [BuildData], period: String) throws -> BuildStatistics {
        // データ検証
        let validatedBuilds = try validator.validate(builds)
        
        guard !validatedBuilds.isEmpty else {
            throw AnalysisError.invalidData("ビルドデータが空です")
        }
        
        // 基本統計の計算
        let totalBuilds = validatedBuilds.count
        let successCount = validatedBuilds.filter { $0.statusText == "success" }.count
        let errorCount = validatedBuilds.filter { $0.statusText == "error" }.count
        let abortedCount = validatedBuilds.filter { $0.statusText == "aborted" }.count
        let successRate = totalBuilds > 0 ? Double(successCount) / Double(totalBuilds) * 100 : 0
        
        // 実行時間の計算（安全な処理）
        let durations = try calculateDurations(for: validatedBuilds)
        
        // 統計値の計算
        let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        let medianDuration = calculateMedian(durations)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        
        let sortedDurations = durations.sorted()
        let p50Duration = calculatePercentile(sortedDurations, 50)
        let p75Duration = calculatePercentile(sortedDurations, 75)
        let p90Duration = calculatePercentile(sortedDurations, 90)
        let p95Duration = calculatePercentile(sortedDurations, 95)
        let p99Duration = calculatePercentile(sortedDurations, 99)
        
        let standardDeviation = calculateStandardDeviation(durations, mean: averageDuration)
        
        // クレジットコストの計算
        let creditCosts = validatedBuilds.compactMap { $0.creditCost }
        let totalCreditCost = creditCosts.reduce(0, +)
        let averageCreditCost = creditCosts.isEmpty ? 0 : Double(totalCreditCost) / Double(creditCosts.count)
        
        return BuildStatistics(
            period: period,
            totalBuilds: totalBuilds,
            successCount: successCount,
            errorCount: errorCount,
            abortedCount: abortedCount,
            successRate: successRate,
            averageDuration: averageDuration,
            medianDuration: medianDuration,
            minDuration: minDuration,
            maxDuration: maxDuration,
            p50Duration: p50Duration,
            p75Duration: p75Duration,
            p90Duration: p90Duration,
            p95Duration: p95Duration,
            p99Duration: p99Duration,
            standardDeviation: standardDeviation,
            totalCreditCost: totalCreditCost,
            averageCreditCost: averageCreditCost
        )
    }
    
    private func calculateDurations(for builds: [BuildData]) throws -> [TimeInterval] {
        var durations: [TimeInterval] = []
        
        for build in builds {
            guard let triggeredAt = build.triggeredAt,
                  let finishedAt = build.finishedAt else { continue }
            
            guard let start = dateFormatter.iso8601Formatter.date(from: triggeredAt),
                  let end = dateFormatter.iso8601Formatter.date(from: finishedAt) else {
                continue
            }
            
            let duration = end.timeIntervalSince(start)
            
            // データ検証
            guard duration >= 0 && duration <= TimeInterval(config.thresholds.maxDurationHours * 3600) else {
                continue
            }
            
            durations.append(duration)
        }
        
        return durations
    }
    
    // 統計計算ユーティリティはUtilsディレクトリに移動済み
}

// MARK: - ワークフロー分析器

class WorkflowAnalyzerImpl: WorkflowAnalyzer {
    private let config: AnalysisConfiguration
    
    init(config: AnalysisConfiguration = .default) {
        self.config = config
    }
    
    func analyzeWorkflows(for builds: [BuildData]) throws -> WorkflowAnalysis {
        let workflowGroups = Dictionary(grouping: builds, by: { $0.triggeredWorkflow ?? "Unknown" })
        
        // 実行回数トップ
        let topWorkflows = workflowGroups
            .mapValues { $0.count }
            .sorted(by: { $0.value > $1.value })
            .prefix(config.thresholds.topWorkflowCount)
            .map { ($0.key, $0.value) }
        
        // 長時間実行ワークフロー
        let longRunningWorkflows = try calculateLongRunningWorkflows(workflowGroups)
        
        // 高失敗率ワークフロー
        let highFailureWorkflows = try calculateHighFailureWorkflows(workflowGroups)
        
        return WorkflowAnalysis(
            topWorkflows: Array(topWorkflows),
            longRunningWorkflows: longRunningWorkflows,
            highFailureWorkflows: highFailureWorkflows
        )
    }
    
    private func calculateLongRunningWorkflows(_ workflowGroups: [String: [BuildData]]) throws -> [(String, TimeInterval)] {
        var results: [(String, TimeInterval)] = []
        
        for (workflow, builds) in workflowGroups {
            let durations = try calculateWorkflowDurations(builds)
            let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
            
            if averageDuration > 0 {
                results.append((workflow, averageDuration))
            }
        }
        
        return results.sorted(by: { $0.1 > $1.1 }).prefix(config.thresholds.topWorkflowCount).map { $0 }
    }
    
    private func calculateHighFailureWorkflows(_ workflowGroups: [String: [BuildData]]) throws -> [(String, Double)] {
        var results: [(String, Double)] = []
        
        for (workflow, builds) in workflowGroups {
            guard builds.count >= config.thresholds.minWorkflowExecutions else { continue }
            
            let failures = builds.filter { $0.statusText == "error" }.count
            let failureRate = Double(failures) / Double(builds.count) * 100
            
            if failureRate >= config.thresholds.minFailureRate {
                results.append((workflow, failureRate))
            }
        }
        
        return results.sorted(by: { $0.1 > $1.1 }).prefix(config.thresholds.topWorkflowCount).map { $0 }
    }
    
    private func calculateWorkflowDurations(_ builds: [BuildData]) throws -> [TimeInterval] {
        let formatter = ISO8601DateFormatter()
        var durations: [TimeInterval] = []
        
        for build in builds {
            guard let triggeredAt = build.triggeredAt,
                  let finishedAt = build.finishedAt,
                  let start = formatter.date(from: triggeredAt),
                  let end = formatter.date(from: finishedAt) else { continue }
            
            let duration = end.timeIntervalSince(start)
            if duration >= 0 {
                durations.append(duration)
            }
        }
        
        return durations
    }
}

// MARK: - リポジトリ分析器

class RepositoryAnalyzerImpl: RepositoryAnalyzer {
    private let config: AnalysisConfiguration
    private let statisticsCalculator: StatisticsCalculator
    
    init(config: AnalysisConfiguration = .default, 
         statisticsCalculator: StatisticsCalculator = ImprovedStatisticsCalculator()) {
        self.config = config
        self.statisticsCalculator = statisticsCalculator
    }
    
    func analyzeRepositories(for builds: [BuildData], periods: [AnalysisPeriod]) throws -> RepositoryAnalysis {
        let repositoryGroups = Dictionary(grouping: builds) { build in
            build.repository?.title ?? "Unknown"
        }
        
        var repositoryStats: [String: [String: BuildStatistics]] = [:]
        var repositoryWorkflows: [String: [String]] = [:]
        var repositoryFailures: [String: [String]] = [:]
        
        for (repository, repoBuilds) in repositoryGroups {
            var periodStats: [String: BuildStatistics] = [:]
            
            for period in periods {
                let filteredBuilds = try filterBuildsByPeriod(repoBuilds, period: period)
                
                if !filteredBuilds.isEmpty {
                    let stats = try statisticsCalculator.calculate(for: filteredBuilds, period: period.name)
                    periodStats[period.name] = stats
                }
            }
            
            if !periodStats.isEmpty {
                repositoryStats[repository] = periodStats
                
                // 主要ワークフローの分析
                let workflows = analyzeRepositoryWorkflows(repoBuilds)
                repositoryWorkflows[repository] = workflows
                
                // 失敗率の高いワークフローの分析
                let failures = analyzeRepositoryFailures(repoBuilds)
                repositoryFailures[repository] = failures
            }
        }
        
        return RepositoryAnalysis(
            repositoryStats: repositoryStats,
            repositoryWorkflows: repositoryWorkflows,
            repositoryFailures: repositoryFailures
        )
    }
    
    private func filterBuildsByPeriod(_ builds: [BuildData], period: AnalysisPeriod) throws -> [BuildData] {
        guard let days = period.days else {
            return builds
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            throw AnalysisError.invalidDateCalculation
        }
        
        let formatter = ISO8601DateFormatter()
        
        return builds.filter { build in
            guard let triggeredAt = build.triggeredAt,
                  let date = formatter.date(from: triggeredAt) else { return false }
            return date >= startDate
        }
    }
    
    private func analyzeRepositoryWorkflows(_ builds: [BuildData]) -> [String] {
        let workflowStats = Dictionary(grouping: builds, by: { $0.triggeredWorkflow ?? "Unknown" })
            .mapValues { $0.count }
            .sorted(by: { $0.value > $1.value })
            .prefix(config.thresholds.topWorkflowCount)
            .map { "\($0.key)(\($0.value))" }
        
        return Array(workflowStats)
    }
    
    private func analyzeRepositoryFailures(_ builds: [BuildData]) -> [String] {
        let failureWorkflows = Dictionary(grouping: builds, by: { $0.triggeredWorkflow ?? "Unknown" })
            .compactMap { (workflow, builds) -> (String, Double)? in
                let total = builds.count
                guard total >= config.thresholds.minWorkflowExecutions else { return nil }
                let failures = builds.filter { $0.statusText == "error" }.count
                let failureRate = Double(failures) / Double(total) * 100
                guard failureRate >= config.thresholds.minFailureRate else { return nil }
                return (workflow, failureRate)
            }
            .sorted(by: { $0.1 > $1.1 })
            .prefix(config.thresholds.topWorkflowCount)
            .map { "\($0.0)(\(String(format: "%.1f", $0.1))%)" }
        
        return Array(failureWorkflows)
    }
}
