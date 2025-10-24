import Foundation

// MARK: - データプロセッサー実装

class DataProcessorImpl: DataProcessor {
    private let config: AnalysisConfiguration
    private let statisticsCalculator: StatisticsCalculator
    private let workflowAnalyzer: WorkflowAnalyzer
    private let repositoryAnalyzer: RepositoryAnalyzer
    private let validator: DataValidator
    
    init(config: AnalysisConfiguration = .default,
         statisticsCalculator: StatisticsCalculator = ImprovedStatisticsCalculator(),
         workflowAnalyzer: WorkflowAnalyzer = WorkflowAnalyzerImpl(),
         repositoryAnalyzer: RepositoryAnalyzer = RepositoryAnalyzerImpl(),
         validator: DataValidator = BuildDataValidator()) {
        self.config = config
        self.statisticsCalculator = statisticsCalculator
        self.workflowAnalyzer = workflowAnalyzer
        self.repositoryAnalyzer = repositoryAnalyzer
        self.validator = validator
    }
    
    func processBuilds(_ builds: [BuildData]) throws -> ProcessedData {
        // データ検証
        let validatedBuilds = try validator.validate(builds)
        
        // 統計計算
        var statistics: [String: BuildStatistics] = [:]
        
        for period in config.periods {
            let filteredBuilds = try filterBuildsByPeriod(validatedBuilds, period: period)
            
            if !filteredBuilds.isEmpty {
                let stats = try statisticsCalculator.calculate(for: filteredBuilds, period: period.name)
                statistics[period.name] = stats
            }
        }
        
        // ワークフロー分析
        let workflowAnalysis = try workflowAnalyzer.analyzeWorkflows(for: validatedBuilds)
        
        // リポジトリ分析
        let repositoryAnalysis = try repositoryAnalyzer.analyzeRepositories(for: validatedBuilds, periods: config.periods)
        
        return ProcessedData(
            builds: validatedBuilds,
            statistics: statistics,
            workflowAnalysis: workflowAnalysis,
            repositoryAnalysis: repositoryAnalysis
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
}

// MARK: - レポートジェネレーター実装

class ReportGeneratorImpl {
    private let config: AnalysisConfiguration
    private let csvGenerator: CSVGenerator
    private let markdownGenerator: MarkdownGenerator
    private let outputManager: OutputManager
    
    init(config: AnalysisConfiguration = .default,
         csvGenerator: CSVGenerator = ImprovedCSVGenerator(),
         markdownGenerator: MarkdownGenerator = MarkdownGeneratorImpl(),
         outputManager: OutputManager = OutputManagerImpl()) {
        self.config = config
        self.csvGenerator = csvGenerator
        self.markdownGenerator = markdownGenerator
        self.outputManager = outputManager
    }
    
    func generateReports(from data: ProcessedData, to directory: URL) async throws {
        
        // CSVレポートの生成
        if config.outputFormats.contains(.csv) {
            try await generateCSVReports(from: data, to: directory)
        }
        
        // Markdownレポートの生成
        if config.outputFormats.contains(.markdown) {
            try await generateMarkdownReports(from: data, to: directory)
        }
        
        // コンソール出力
        printConsoleSummary(statistics: data.statistics)
    }
    
    private func generateCSVReports(from data: ProcessedData, to directory: URL) async throws {
        // 基本統計CSV
        let summaryCSV = try csvGenerator.generateCSV(from: data.statistics)
        try outputManager.writeCSV(summaryCSV, filename: "builds_summary.csv", to: directory)
        
        // リポジトリ統計CSV
        let repositoryCSV = try csvGenerator.generateCSV(from: data.repositoryAnalysis)
        try outputManager.writeCSV(repositoryCSV, filename: "repository_stats.csv", to: directory)
        
        // ワークフロー統計CSV
        let workflowCSV = try csvGenerator.generateCSV(from: data.workflowAnalysis)
        try outputManager.writeCSV(workflowCSV, filename: "workflow_stats.csv", to: directory)
        
        // 日別トレンドCSV
        let dailyCSV = try generateDailyTrendCSV(builds: data.builds)
        try outputManager.writeCSV(dailyCSV, filename: "daily_trends.csv", to: directory)
        
        // 時間帯分布CSV
        let hourlyCSV = try generateHourlyDistributionCSV(builds: data.builds)
        try outputManager.writeCSV(hourlyCSV, filename: "hourly_distribution.csv", to: directory)
        
        // マシンタイプ統計CSV
        let machineCSV = try generateMachineTypeCSV(builds: data.builds)
        try outputManager.writeCSV(machineCSV, filename: "machine_type_stats.csv", to: directory)
    }
    
    private func generateMarkdownReports(from data: ProcessedData, to directory: URL) async throws {
        for (period, stats) in data.statistics {
            let markdown = try markdownGenerator.generateMarkdown(from: (stats, period))
            try outputManager.writeMarkdown(markdown, filename: "report_\(period).md", to: directory)
        }
    }
    
    private func printConsoleSummary(statistics: [String: BuildStatistics]) {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 Bitrise ビルド統計サマリー")
        print(String(repeating: "=", count: 60))
        
        for (period, stat) in statistics {
            print("\n📈 \(period)期間:")
            print("  📦 総ビルド数: \(stat.totalBuilds)")
            print("  ✅ 成功: \(stat.successCount) (\(String(format: "%.1f", stat.successRate))%)")
            print("  ❌ 失敗: \(stat.errorCount)")
            print("  ⏹️  中断: \(stat.abortedCount)")
            print("  ⏱️  平均実行時間: \(formatDuration(stat.averageDuration))")
            print("  📊 中央値: \(formatDuration(stat.medianDuration))")
            print("  💰 総コスト: \(stat.totalCreditCost) credits")
        }
        
        print("\n" + String(repeating: "=", count: 60))
    }
    
    // MARK: - 追加CSV生成メソッド
    
    private func generateDailyTrendCSV(builds: [BuildData]) throws -> String {
        var csv = "日付,ビルド数,成功数,失敗数,平均実行時間(分)\n"
        
        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let dailyStats = Dictionary(grouping: builds) { build in
            guard let triggeredAt = build.triggeredAt,
                  let date = formatter.date(from: triggeredAt) else { return "Unknown" }
            return dateFormatter.string(from: date)
        }
        
        for (date, builds) in dailyStats.sorted(by: { $0.key < $1.key }) {
            let total = builds.count
            let success = builds.filter { $0.statusText == "success" }.count
            let failure = builds.filter { $0.statusText == "error" }.count
            
            let durations = builds.compactMap { build -> TimeInterval? in
                guard let triggeredAt = build.triggeredAt,
                      let finishedAt = build.finishedAt else { return nil }
                
                guard let start = formatter.date(from: triggeredAt),
                      let end = formatter.date(from: finishedAt) else { return nil }
                
                return end.timeIntervalSince(start)
            }
            
            let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
            
            csv += "\(date),\(total),\(success),\(failure),\(String(format: "%.2f", averageDuration/60))\n"
        }
        
        return csv
    }
    
    private func generateHourlyDistributionCSV(builds: [BuildData]) throws -> String {
        var csv = "時間,ビルド数,成功率(%)\n"
        
        let formatter = ISO8601DateFormatter()
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "HH"
        
        let hourlyStats = Dictionary(grouping: builds) { build in
            guard let triggeredAt = build.triggeredAt,
                  let date = formatter.date(from: triggeredAt) else { return "Unknown" }
            return hourFormatter.string(from: date)
        }
        
        for hour in 0...23 {
            let hourStr = String(format: "%02d", hour)
            let builds = hourlyStats[hourStr] ?? []
            let total = builds.count
            let success = builds.filter { $0.statusText == "success" }.count
            let successRate = total > 0 ? Double(success) / Double(total) * 100 : 0
            
            csv += "\(hourStr):00,\(total),\(String(format: "%.1f", successRate))\n"
        }
        
        return csv
    }
    
    private func generateMachineTypeCSV(builds: [BuildData]) throws -> String {
        var csv = "マシンタイプ,使用回数,使用率(%),平均実行時間(分),総実行時間(分),総コスト\n"
        
        let totalBuilds = builds.count
        let machineStats = Dictionary(grouping: builds, by: { $0.machineTypeId ?? "Unknown" })
            .mapValues { builds in
                let count = builds.count
                let usageRate = totalBuilds > 0 ? Double(count) / Double(totalBuilds) * 100 : 0
                
                let durations = builds.compactMap { build -> TimeInterval? in
                    guard let triggeredAt = build.triggeredAt,
                          let finishedAt = build.finishedAt else { return nil }
                    
                    let formatter = ISO8601DateFormatter()
                    guard let start = formatter.date(from: triggeredAt),
                          let end = formatter.date(from: finishedAt) else { return nil }
                    
                    return end.timeIntervalSince(start)
                }
                
                let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
                let totalDuration = durations.reduce(0, +)
                let totalCost = builds.compactMap { $0.creditCost }.reduce(0, +)
                
                return (count, usageRate, averageDuration, totalDuration, totalCost)
            }
        
        for (machineType, stats) in machineStats.sorted(by: { $0.value.0 > $1.value.0 }) {
            csv += "\(machineType),\(stats.0),\(String(format: "%.1f", stats.1)),\(String(format: "%.2f", stats.2/60)),\(String(format: "%.2f", stats.3/60)),\(stats.4)\n"
        }
        
        return csv
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Markdownジェネレーター実装

class MarkdownGeneratorImpl: MarkdownGenerator {
    func generateMarkdown(from data: Any) throws -> String {
        guard let (stats, period) = data as? (BuildStatistics, String) else {
            throw AnalysisError.calculationFailed("無効なデータ型です")
        }
        
        return """
        # Bitrise ビルド統計レポート - \(period)期間
        
        ## 基本統計
        
        | 項目 | 値 |
        |------|-----|
        | 総ビルド数 | \(stats.totalBuilds) |
        | 成功 | \(stats.successCount) (\(String(format: "%.1f", stats.successRate))%) |
        | 失敗 | \(stats.errorCount) |
        | 中断 | \(stats.abortedCount) |
        
        ## 実行時間統計
        
        | 項目 | 値 |
        |------|-----|
        | 平均 | \(formatDuration(stats.averageDuration)) |
        | 中央値 | \(formatDuration(stats.medianDuration)) |
        | 最小 | \(formatDuration(stats.minDuration)) |
        | 最大 | \(formatDuration(stats.maxDuration)) |
        | P50 | \(formatDuration(stats.p50Duration)) |
        | P75 | \(formatDuration(stats.p75Duration)) |
        | P90 | \(formatDuration(stats.p90Duration)) |
        | P95 | \(formatDuration(stats.p95Duration)) |
        | P99 | \(formatDuration(stats.p99Duration)) |
        | 標準偏差 | \(formatDuration(stats.standardDeviation)) |
        
        ## コスト統計
        
        | 項目 | 値 |
        |------|-----|
        | 総コスト | \(stats.totalCreditCost) credits |
        | 平均コスト | \(String(format: "%.2f", stats.averageCreditCost)) credits |
        
        """
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
