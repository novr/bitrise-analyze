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
    
    // 日付フィルタリングはUtilsディレクトリに移動済み
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
        printConsoleSummary(stats: data.statistics)
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
        let dailyCSV = generateDailyTrendCSV(builds: data.builds)
        try outputManager.writeCSV(dailyCSV, filename: "daily_trends.csv", to: directory)
        
        // 時間帯分布CSV
        let hourlyCSV = generateHourlyDistributionCSV(builds: data.builds)
        try outputManager.writeCSV(hourlyCSV, filename: "hourly_distribution.csv", to: directory)
        
        // マシンタイプ統計CSV
        let machineCSV = generateMachineTypeCSV(builds: data.builds)
        try outputManager.writeCSV(machineCSV, filename: "machine_type_stats.csv", to: directory)
    }
    
    private func generateMarkdownReports(from data: ProcessedData, to directory: URL) async throws {
        for (period, stats) in data.statistics {
            let markdown = try markdownGenerator.generateMarkdown(from: (stats, period))
            try outputManager.writeMarkdown(markdown, filename: "report_\(period).md", to: directory)
        }
    }
    
    // ユーティリティ関数はUtilsディレクトリに移動済み
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
