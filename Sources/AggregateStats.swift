import Foundation
import ArgumentParser

struct AggregateStats: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aggregate",
        abstract: "Bitriseビルドデータの集計とレポート生成"
    )
    
    @Option(name: .shortAndLong, help: "データファイルのパス")
    var input: String = "data.json"
    
    @Option(name: .shortAndLong, help: "出力ディレクトリ")
    var output: String = "output"
    
    @Flag(name: .shortAndLong, help: "詳細なログを表示")
    var verbose: Bool = false
    
    @Option(name: .shortAndLong, help: "設定ファイルのパス")
    var config: String?
    
    mutating func run() async throws {
        print("📊 Bitriseデータ集計を開始します...")
        
        // 設定の読み込み
        let analysisConfig = try loadConfiguration()
        
        // 出力ディレクトリを作成
        let outputURL = URL(filePath: output)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        // JSONデータを読み込み
        let data = try Data(contentsOf: URL(filePath: input))
        let builds = try JSONDecoder().decode([BuildData].self, from: data)
        
        if verbose {
            print("📁 読み込み完了: \(builds.count)件のビルドデータ")
        }
        
        // データ処理の実行
        let processor = DataProcessorImpl(config: analysisConfig)
        let processedData = try processor.processBuilds(builds)
        
        // レポート生成
        let reportGenerator = ReportGeneratorImpl(config: analysisConfig)
        try await reportGenerator.generateReports(from: processedData, to: outputURL)
        
        print("✅ 集計完了！出力ディレクトリ: \(output)")
    }
    
    private func loadConfiguration() throws -> AnalysisConfiguration {
        if let configPath = config {
            let configData = try Data(contentsOf: URL(filePath: configPath))
            return try JSONDecoder().decode(AnalysisConfiguration.self, from: configData)
        } else {
            return .default
        }
    }
}

// MARK: - データ構造

struct BuildData: Codable {
    let branch: String?
    let buildNumber: Int?
    let commitHash: String?
    let commitMessage: String?
    let commitViewUrl: String?
    let creditCost: Int?
    let environmentPrepareFinishedAt: String?
    let finishedAt: String?
    let isOnHold: Bool?
    let isProcessed: Bool?
    let machineTypeId: String?
    let pullRequestId: Int?
    let pullRequestTargetBranch: String?
    let pullRequestViewUrl: String?
    let repository: Repository?
    let slug: String?
    let stackIdentifier: String?
    let startedOnWorkerAt: String?
    let status: Int?
    let statusText: String?
    let triggeredAt: String?
    let triggeredBy: String?
    let triggeredWorkflow: String?
    
    enum CodingKeys: String, CodingKey {
        case branch
        case buildNumber = "build_number"
        case commitHash = "commit_hash"
        case commitMessage = "commit_message"
        case commitViewUrl = "commit_view_url"
        case creditCost = "credit_cost"
        case environmentPrepareFinishedAt = "environment_prepare_finished_at"
        case finishedAt = "finished_at"
        case isOnHold = "is_on_hold"
        case isProcessed = "is_processed"
        case machineTypeId = "machine_type_id"
        case pullRequestId = "pull_request_id"
        case pullRequestTargetBranch = "pull_request_target_branch"
        case pullRequestViewUrl = "pull_request_view_url"
        case repository
        case slug
        case stackIdentifier = "stack_identifier"
        case startedOnWorkerAt = "started_on_worker_at"
        case status
        case statusText = "status_text"
        case triggeredAt = "triggered_at"
        case triggeredBy = "triggered_by"
        case triggeredWorkflow = "triggered_workflow"
    }
}

struct Repository: Codable {
    let isDisabled: Bool?
    let isGithubChecksEnabled: Bool?
    let isPublic: Bool?
    let owner: Owner?
    let projectType: String?
    let provider: String?
    let repoOwner: String?
    let repoSlug: String?
    let repoUrl: String?
    let slug: String?
    let status: Int?
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case isDisabled = "is_disabled"
        case isGithubChecksEnabled = "is_github_checks_enabled"
        case isPublic = "is_public"
        case owner
        case projectType = "project_type"
        case provider
        case repoOwner = "repo_owner"
        case repoSlug = "repo_slug"
        case repoUrl = "repo_url"
        case slug
        case status
        case title
    }
}

struct Owner: Codable {
    let accountType: String?
    let name: String?
    let slug: String?
    
    enum CodingKeys: String, CodingKey {
        case accountType = "account_type"
        case name
        case slug
    }
}

// MARK: - 統計データ構造

struct BuildStatistics {
    let period: String
    let totalBuilds: Int
    let successCount: Int
    let errorCount: Int
    let abortedCount: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let medianDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let p50Duration: TimeInterval
    let p75Duration: TimeInterval
    let p90Duration: TimeInterval
    let p95Duration: TimeInterval
    let p99Duration: TimeInterval
    let standardDeviation: TimeInterval
    let totalCreditCost: Int
    let averageCreditCost: Double
}

// MARK: - 統計計算

func calculateStatistics(for builds: [BuildData], period: String) -> BuildStatistics {
    let totalBuilds = builds.count
    
    // ステータス別集計
    let successCount = builds.filter { $0.statusText == "success" }.count
    let errorCount = builds.filter { $0.statusText == "error" }.count
    let abortedCount = builds.filter { $0.statusText == "aborted" }.count
    let successRate = totalBuilds > 0 ? Double(successCount) / Double(totalBuilds) * 100 : 0
    
    // 実行時間の計算
    let durations = builds.compactMap { build -> TimeInterval? in
        guard let triggeredAt = build.triggeredAt,
              let finishedAt = build.finishedAt else { return nil }
        
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: triggeredAt),
              let end = formatter.date(from: finishedAt) else { return nil }
        
        return end.timeIntervalSince(start)
    }
    
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
    
    // クレジットコスト
    let creditCosts = builds.compactMap { $0.creditCost }
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

// MARK: - 統計計算ヘルパー関数

func calculateMedian(_ values: [TimeInterval]) -> TimeInterval {
    let sorted = values.sorted()
    let count = sorted.count
    
    if count == 0 { return 0 }
    if count % 2 == 0 {
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    } else {
        return sorted[count / 2]
    }
}

func calculatePercentile(_ sortedValues: [TimeInterval], _ percentile: Int) -> TimeInterval {
    if sortedValues.isEmpty { return 0 }
    
    let index = Int(ceil(Double(sortedValues.count) * Double(percentile) / 100.0)) - 1
    return sortedValues[min(index, sortedValues.count - 1)]
}

func calculateStandardDeviation(_ values: [TimeInterval], mean: TimeInterval) -> TimeInterval {
    if values.isEmpty { return 0 }
    
    let squaredDifferences = values.map { pow($0 - mean, 2) }
    let variance = squaredDifferences.reduce(0, +) / Double(values.count)
    return sqrt(variance)
}

// MARK: - レポート生成

func generateReports(stats: [String: BuildStatistics], builds: [BuildData], outputURL: URL) async throws {
    // コンソール出力
    printConsoleSummary(stats: stats)
    
    // Markdownレポート生成
    for (period, stat) in stats {
        let markdown = generateMarkdownReport(stat: stat, builds: builds, period: period)
        let markdownURL = outputURL.appendingPathComponent("report_\(period).md")
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
    }
    
    // CSV出力
    try generateCSVReports(stats: stats, builds: builds, outputURL: outputURL)
    
    // リポジトリ別集計CSV
    try generateRepositoryCSV(builds: builds, outputURL: outputURL)
}

func printConsoleSummary(stats: [String: BuildStatistics]) {
    print("\n" + String(repeating: "=", count: 60))
    print("📊 Bitrise ビルド統計サマリー")
    print(String(repeating: "=", count: 60))
    
    for (period, stat) in stats {
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

func generateMarkdownReport(stat: BuildStatistics, builds: [BuildData], period: String) -> String {
    let markdown = """
    # Bitrise ビルド統計レポート - \(period)期間
    
    ## 基本統計
    
    | 項目 | 値 |
    |------|-----|
    | 総ビルド数 | \(stat.totalBuilds) |
    | 成功 | \(stat.successCount) (\(String(format: "%.1f", stat.successRate))%) |
    | 失敗 | \(stat.errorCount) |
    | 中断 | \(stat.abortedCount) |
    
    ## 実行時間統計
    
    | 項目 | 値 |
    |------|-----|
    | 平均 | \(formatDuration(stat.averageDuration)) |
    | 中央値 | \(formatDuration(stat.medianDuration)) |
    | 最小 | \(formatDuration(stat.minDuration)) |
    | 最大 | \(formatDuration(stat.maxDuration)) |
    | P50 | \(formatDuration(stat.p50Duration)) |
    | P75 | \(formatDuration(stat.p75Duration)) |
    | P90 | \(formatDuration(stat.p90Duration)) |
    | P95 | \(formatDuration(stat.p95Duration)) |
    | P99 | \(formatDuration(stat.p99Duration)) |
    | 標準偏差 | \(formatDuration(stat.standardDeviation)) |
    
    ## コスト統計
    
    | 項目 | 値 |
    |------|-----|
    | 総コスト | \(stat.totalCreditCost) credits |
    | 平均コスト | \(String(format: "%.2f", stat.averageCreditCost)) credits |
    
    """
    
    return markdown
}

func generateCSVReports(stats: [String: BuildStatistics], builds: [BuildData], outputURL: URL) throws {
    // 基本統計CSV
    let summaryCSV = generateSummaryCSV(stats: stats)
    let summaryURL = outputURL.appendingPathComponent("builds_summary.csv")
    try summaryCSV.write(to: summaryURL, atomically: true, encoding: .utf8)
    
    // ワークフロー統計CSV
    let workflowCSV = generateWorkflowCSV(builds: builds)
    let workflowURL = outputURL.appendingPathComponent("workflow_stats.csv")
    try workflowCSV.write(to: workflowURL, atomically: true, encoding: .utf8)
    
    // 日別トレンドCSV
    let dailyCSV = generateDailyTrendCSV(builds: builds)
    let dailyURL = outputURL.appendingPathComponent("daily_trends.csv")
    try dailyCSV.write(to: dailyURL, atomically: true, encoding: .utf8)
    
    // 時間帯分布CSV
    let hourlyCSV = generateHourlyDistributionCSV(builds: builds)
    let hourlyURL = outputURL.appendingPathComponent("hourly_distribution.csv")
    try hourlyCSV.write(to: hourlyURL, atomically: true, encoding: .utf8)
    
    // マシンタイプ統計CSV
    let machineCSV = generateMachineTypeCSV(builds: builds)
    let machineURL = outputURL.appendingPathComponent("machine_type_stats.csv")
    try machineCSV.write(to: machineURL, atomically: true, encoding: .utf8)
}

func generateSummaryCSV(stats: [String: BuildStatistics]) -> String {
    var csv = "期間,総ビルド数,成功数,失敗数,中断数,成功率(%),平均実行時間(分),中央値(分),最小(分),最大(分),P50(分),P75(分),P90(分),P95(分),P99(分),標準偏差(分),総コスト,平均コスト\n"
    
    for (period, stat) in stats {
        csv += "\(period),\(stat.totalBuilds),\(stat.successCount),\(stat.errorCount),\(stat.abortedCount),\(String(format: "%.1f", stat.successRate)),\(String(format: "%.2f", stat.averageDuration/60)),\(String(format: "%.2f", stat.medianDuration/60)),\(String(format: "%.2f", stat.minDuration/60)),\(String(format: "%.2f", stat.maxDuration/60)),\(String(format: "%.2f", stat.p50Duration/60)),\(String(format: "%.2f", stat.p75Duration/60)),\(String(format: "%.2f", stat.p90Duration/60)),\(String(format: "%.2f", stat.p95Duration/60)),\(String(format: "%.2f", stat.p99Duration/60)),\(String(format: "%.2f", stat.standardDeviation/60)),\(stat.totalCreditCost),\(String(format: "%.2f", stat.averageCreditCost))\n"
    }
    
    return csv
}

func generateWorkflowCSV(builds: [BuildData]) -> String {
    var csv = "ワークフロー,実行回数,成功率(%),平均実行時間(分),総実行時間(分),失敗回数\n"
    
    let workflowStats = Dictionary(grouping: builds, by: { $0.triggeredWorkflow ?? "Unknown" })
        .mapValues { builds in
            let total = builds.count
            let success = builds.filter { $0.statusText == "success" }.count
            let successRate = total > 0 ? Double(success) / Double(total) * 100 : 0
            
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
            let failureCount = builds.filter { $0.statusText == "error" }.count
            
            return (total, successRate, averageDuration, totalDuration, failureCount)
        }
    
    for (workflow, stats) in workflowStats.sorted(by: { $0.value.0 > $1.value.0 }) {
        csv += "\(workflow),\(stats.0),\(String(format: "%.1f", stats.1)),\(String(format: "%.2f", stats.2/60)),\(String(format: "%.2f", stats.3/60)),\(stats.4)\n"
    }
    
    return csv
}

func generateDailyTrendCSV(builds: [BuildData]) -> String {
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

func generateHourlyDistributionCSV(builds: [BuildData]) -> String {
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

func generateMachineTypeCSV(builds: [BuildData]) -> String {
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

func generateRepositoryCSV(builds: [BuildData], outputURL: URL) throws {
    var csv = "リポジトリ,期間,総ビルド数,成功数,失敗数,中断数,成功率(%),平均実行時間(分),中央値(分),最小(分),最大(分),P50(分),P75(分),P90(分),P95(分),P99(分),標準偏差(分),総コスト,平均コスト,主要ワークフロー,失敗率の高いワークフロー\n"
    
    // リポジトリ別にグループ化
    let repositoryGroups = Dictionary(grouping: builds) { build in
        build.repository?.title ?? "Unknown"
    }
    
    let now = Date()
    let calendar = Calendar.current
    let periods = [
        ("7日", 7),
        ("30日", 30),
        ("90日", 90),
        ("全期間", nil)
    ]
    
    for (repository, repoBuilds) in repositoryGroups {
        for (periodName, days) in periods {
            let filteredBuilds: [BuildData]
            if let days = days {
                let startDate = calendar.date(byAdding: .day, value: -days, to: now)!
                filteredBuilds = repoBuilds.filter { build in
                    guard let triggeredAt = build.triggeredAt else { return false }
                    let formatter = ISO8601DateFormatter()
                    guard let date = formatter.date(from: triggeredAt) else { return false }
                    return date >= startDate
                }
            } else {
                filteredBuilds = repoBuilds
            }
            
            if filteredBuilds.isEmpty { continue }
            
            let stats = calculateStatistics(for: filteredBuilds, period: periodName)
            
            // 主要ワークフロー（実行回数トップ3）
            let workflowStats = Dictionary(grouping: filteredBuilds, by: { $0.triggeredWorkflow ?? "Unknown" })
                .mapValues { $0.count }
                .sorted(by: { $0.value > $1.value })
                .prefix(3)
                .map { "\($0.key)(\($0.value))" }
                .joined(separator: "; ")
            
            // 失敗率の高いワークフロー（失敗率50%以上、実行回数5回以上）
            let failureWorkflows = Dictionary(grouping: filteredBuilds, by: { $0.triggeredWorkflow ?? "Unknown" })
                .compactMap { (workflow, builds) -> (String, Double)? in
                    let total = builds.count
                    guard total >= 5 else { return nil }
                    let failures = builds.filter { $0.statusText == "error" }.count
                    let failureRate = Double(failures) / Double(total) * 100
                    guard failureRate >= 50 else { return nil }
                    return (workflow, failureRate)
                }
                .sorted(by: { $0.1 > $1.1 })
                .prefix(3)
                .map { "\($0.0)(\(String(format: "%.1f", $0.1))%)" }
                .joined(separator: "; ")
            
            csv += "\(repository),\(periodName),\(stats.totalBuilds),\(stats.successCount),\(stats.errorCount),\(stats.abortedCount),\(String(format: "%.1f", stats.successRate)),\(String(format: "%.2f", stats.averageDuration/60)),\(String(format: "%.2f", stats.medianDuration/60)),\(String(format: "%.2f", stats.minDuration/60)),\(String(format: "%.2f", stats.maxDuration/60)),\(String(format: "%.2f", stats.p50Duration/60)),\(String(format: "%.2f", stats.p75Duration/60)),\(String(format: "%.2f", stats.p90Duration/60)),\(String(format: "%.2f", stats.p95Duration/60)),\(String(format: "%.2f", stats.p99Duration/60)),\(String(format: "%.2f", stats.standardDeviation/60)),\(stats.totalCreditCost),\(String(format: "%.2f", stats.averageCreditCost)),\"\(workflowStats)\",\"\(failureWorkflows)\"\n"
        }
    }
    
    let repositoryURL = outputURL.appendingPathComponent("repository_stats.csv")
    try csv.write(to: repositoryURL, atomically: true, encoding: .utf8)
}

// MARK: - ユーティリティ関数

func formatDuration(_ duration: TimeInterval) -> String {
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
