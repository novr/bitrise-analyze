import Foundation

// MARK: - レポート生成ユーティリティ

/// レポートを生成する
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

/// コンソールサマリーを出力する
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

/// 30日データでビルド数・総時間のトップAppをコンソールに出力
func printTopAppsSummary(analysis: RepositoryAnalysis, topN: Int = 10) {
    typealias RepoStat = (repository: String, builds: Int, avgMinutes: Double, totalMinutes: Double, successRate: Double)
    var rows: [RepoStat] = []
    for (repo, periodStats) in analysis.repositoryStats {
        guard let stats = periodStats["30日"] else { continue }
        let avgMin = stats.averageDuration / 60
        let totalMin = Double(stats.totalBuilds) * avgMin
        rows.append((repo, stats.totalBuilds, avgMin, totalMin, stats.successRate))
    }
    if rows.isEmpty { return }
    
    func formatDuration(_ minutes: Double) -> String {
        if minutes < 60 { return String(format: "%.1f分", minutes) }
        if minutes < 1440 { return String(format: "%.1f時間", minutes / 60) }
        return String(format: "%.1f日", minutes / 1440)
    }
    
    func pad(_ s: String, _ length: Int) -> String {
        let t = String(s.prefix(length))
        return t + String(repeating: " ", count: max(0, length - t.count))
    }
    
    print("\n" + String(repeating: "=", count: 80))
    print("📊 ビルド数の多いApp（30日間・トップ\(topN)）")
    print(String(repeating: "=", count: 80))
    print(pad("順位", 4) + pad("App名", 35) + pad("ビルド数", 10) + pad("平均時間", 12) + pad("総時間", 15) + "成功率")
    print(String(repeating: "-", count: 80))
    for (i, r) in rows.sorted(by: { $0.builds > $1.builds }).prefix(topN).enumerated() {
        let repo = String(r.repository.replacingOccurrences(of: "\n", with: " ").prefix(34))
        let line = pad(String(i + 1), 4) + pad(repo, 35) + pad(String(r.builds), 10) + pad(formatDuration(r.avgMinutes), 12) + pad(formatDuration(r.totalMinutes), 15) + String(format: "%.1f%%", r.successRate)
        print(line)
    }
    
    print("\n" + String(repeating: "=", count: 80))
    print("⏱️  総ビルド時間の多いApp（30日間・トップ\(topN)）")
    print(String(repeating: "=", count: 80))
    print(pad("順位", 4) + pad("App名", 35) + pad("総時間", 15) + pad("ビルド数", 10) + pad("平均時間", 12) + "成功率")
    print(String(repeating: "-", count: 80))
    for (i, r) in rows.sorted(by: { $0.totalMinutes > $1.totalMinutes }).prefix(topN).enumerated() {
        let repo = String(r.repository.replacingOccurrences(of: "\n", with: " ").prefix(34))
        let line = pad(String(i + 1), 4) + pad(repo, 35) + pad(formatDuration(r.totalMinutes), 15) + pad(String(r.builds), 10) + pad(formatDuration(r.avgMinutes), 12) + String(format: "%.1f%%", r.successRate)
        print(line)
    }
    
    let totalBuilds = rows.map(\.builds).reduce(0, +)
    let totalMinutes = rows.map(\.totalMinutes).reduce(0, +)
    print("\n" + String(repeating: "=", count: 80))
    print("📈 サマリー（30日間）")
    print(String(repeating: "=", count: 80))
    print("総App数: \(rows.count)")
    print("総ビルド数: \(totalBuilds)")
    print("総ビルド時間: \(formatDuration(totalMinutes))")
    print(String(repeating: "=", count: 80))
}

/// Markdownレポートを生成する
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

/// CSVレポートを生成する
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
