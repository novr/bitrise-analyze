import Foundation

// MARK: - 統計計算ユーティリティ

/// ビルドデータから統計を計算する
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
