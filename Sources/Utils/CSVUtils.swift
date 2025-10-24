import Foundation

// MARK: - CSV生成ユーティリティ

/// 基本統計CSVを生成する
func generateSummaryCSV(stats: [String: BuildStatistics]) -> String {
    var csv = "期間,総ビルド数,成功数,失敗数,中断数,成功率(%),平均実行時間(分),中央値(分),最小(分),最大(分),P50(分),P75(分),P90(分),P95(分),P99(分),標準偏差(分),総コスト,平均コスト\n"
    
    for (period, stat) in stats {
        csv += "\(period),\(stat.totalBuilds),\(stat.successCount),\(stat.errorCount),\(stat.abortedCount),\(String(format: "%.1f", stat.successRate)),\(String(format: "%.2f", stat.averageDuration/60)),\(String(format: "%.2f", stat.medianDuration/60)),\(String(format: "%.2f", stat.minDuration/60)),\(String(format: "%.2f", stat.maxDuration/60)),\(String(format: "%.2f", stat.p50Duration/60)),\(String(format: "%.2f", stat.p75Duration/60)),\(String(format: "%.2f", stat.p90Duration/60)),\(String(format: "%.2f", stat.p95Duration/60)),\(String(format: "%.2f", stat.p99Duration/60)),\(String(format: "%.2f", stat.standardDeviation/60)),\(stat.totalCreditCost),\(String(format: "%.2f", stat.averageCreditCost))\n"
    }
    
    return csv
}

/// ワークフロー統計CSVを生成する
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

/// 日別トレンドCSVを生成する
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

/// 時間帯分布CSVを生成する
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

/// マシンタイプ統計CSVを生成する
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

/// リポジトリ統計CSVを生成する
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

/// CSV値をエスケープする
func escapeCSV(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return value
}
