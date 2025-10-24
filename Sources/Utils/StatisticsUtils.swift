import Foundation

// MARK: - 統計計算ユーティリティ

/// 中央値を計算する
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

/// パーセンタイルを計算する
func calculatePercentile(_ sortedValues: [TimeInterval], _ percentile: Int) -> TimeInterval {
    if sortedValues.isEmpty { return 0 }
    
    let index = Int(ceil(Double(sortedValues.count) * Double(percentile) / 100.0)) - 1
    return sortedValues[min(index, sortedValues.count - 1)]
}

/// 標準偏差を計算する
func calculateStandardDeviation(_ values: [TimeInterval], mean: TimeInterval) -> TimeInterval {
    if values.isEmpty { return 0 }
    
    let squaredDifferences = values.map { pow($0 - mean, 2) }
    let variance = squaredDifferences.reduce(0, +) / Double(values.count)
    return sqrt(variance)
}

/// 時間間隔をフォーマットする
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
