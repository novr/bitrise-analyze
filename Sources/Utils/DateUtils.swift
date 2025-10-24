import Foundation

// MARK: - 日付処理ユーティリティ

/// 期間でビルドをフィルタリングする
func filterBuildsByPeriod(_ builds: [BuildData], period: AnalysisPeriod) throws -> [BuildData] {
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

/// ビルドの実行時間を計算する
func calculateBuildDuration(_ build: BuildData) -> TimeInterval? {
    guard let triggeredAt = build.triggeredAt,
          let finishedAt = build.finishedAt else { return nil }
    
    let formatter = ISO8601DateFormatter()
    guard let start = formatter.date(from: triggeredAt),
          let end = formatter.date(from: finishedAt) else { return nil }
    
    return end.timeIntervalSince(start)
}

/// 日付文字列をDateに変換する
func parseDate(_ dateString: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: dateString)
}

/// 日付を文字列にフォーマットする
func formatDate(_ date: Date, format: String = "yyyy-MM-dd") -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}

/// 時間を文字列にフォーマットする
func formatTime(_ date: Date, format: String = "HH:mm") -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}

/// 時間帯を取得する
func getHourFromDate(_ date: Date) -> Int {
    let calendar = Calendar.current
    return calendar.component(.hour, from: date)
}
