import Foundation

// MARK: - データ検証器

class BuildDataValidator: DataValidator {
    private let config: AnalysisConfiguration
    
    init(config: AnalysisConfiguration = .default) {
        self.config = config
    }
    
    func validate(_ builds: [BuildData]) throws -> [BuildData] {
        var validatedBuilds: [BuildData] = []
        var errors: [String] = []
        
        for (index, build) in builds.enumerated() {
            do {
                let validatedBuild = try validateBuild(build)
                validatedBuilds.append(validatedBuild)
            } catch {
                errors.append("ビルド \(index): \(error.localizedDescription)")
            }
        }
        
        if errors.count > builds.count / 2 {
            throw AnalysisError.invalidData("半数以上のビルドデータが無効です: \(errors.joined(separator: "; "))")
        }
        
        return validatedBuilds
    }
    
    private func validateBuild(_ build: BuildData) throws -> BuildData {
        // 必須フィールドの検証
        guard let triggeredAt = build.triggeredAt,
              let statusText = build.statusText else {
            throw AnalysisError.invalidData("必須フィールドが不足しています")
        }
        
        // 日付の検証
        let formatter = ISO8601DateFormatter()
        guard let triggerDate = formatter.date(from: triggeredAt) else {
            throw AnalysisError.invalidData("無効な日付形式: \(triggeredAt)")
        }
        
        // 実行時間の検証（finishedAtがある場合）
        if let finishedAt = build.finishedAt {
            guard let finishDate = formatter.date(from: finishedAt) else {
                throw AnalysisError.invalidData("無効な終了日付: \(finishedAt)")
            }
            
            let duration = finishDate.timeIntervalSince(triggerDate)
            if duration < 0 {
                throw AnalysisError.invalidData("終了時刻が開始時刻より前です")
            }
            
            if duration > TimeInterval(config.thresholds.maxDurationHours * 3600) {
                throw AnalysisError.invalidData("実行時間が異常に長いです: \(duration)秒")
            }
        }
        
        // ステータスの検証
        let validStatuses = ["success", "error", "aborted"]
        guard validStatuses.contains(statusText) else {
            throw AnalysisError.invalidData("無効なステータス: \(statusText)")
        }
        
        return build
    }
}

// MARK: - 日付フォーマッタープロバイダー

class DefaultDateFormatterProvider: DateFormatterProvider {
    private let _iso8601Formatter: ISO8601DateFormatter
    private let _displayFormatter: DateFormatter
    
    init() {
        self._iso8601Formatter = ISO8601DateFormatter()
        self._displayFormatter = DateFormatter()
        self._displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    var iso8601Formatter: ISO8601DateFormatter {
        return _iso8601Formatter
    }
    
    var displayFormatter: DateFormatter {
        return _displayFormatter
    }
}

// MARK: - CSVエスケープ処理

class CSVEscaperImpl: CSVEscaper {
    func escape(_ value: String) -> String {
        // カンマ、ダブルクォート、改行が含まれている場合はエスケープ
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// MARK: - 出力マネージャー

class OutputManagerImpl: OutputManager {
    private let fileManager = FileManager.default
    
    func writeReports(_ reports: [Report], to directory: URL) throws {
        try createDirectoryIfNeeded(directory)
        
        for report in reports {
            let fileURL = directory.appendingPathComponent(report.filename)
            try report.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func writeCSV(_ csv: String, filename: String, to directory: URL) throws {
        try createDirectoryIfNeeded(directory)
        let fileURL = directory.appendingPathComponent(filename)
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func writeMarkdown(_ markdown: String, filename: String, to directory: URL) throws {
        try createDirectoryIfNeeded(directory)
        let fileURL = directory.appendingPathComponent(filename)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func createDirectoryIfNeeded(_ directory: URL) throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

// MARK: - 改善されたCSVジェネレーター

class ImprovedCSVGenerator: CSVGenerator {
    private let escaper: CSVEscaper
    
    init(escaper: CSVEscaper = CSVEscaperImpl()) {
        self.escaper = escaper
    }
    
    func generateCSV(from data: Any) throws -> String {
        switch data {
        case let stats as [String: BuildStatistics]:
            return try generateSummaryCSV(stats)
        case let repositoryAnalysis as RepositoryAnalysis:
            return try generateRepositoryCSV(repositoryAnalysis)
        case let workflowAnalysis as WorkflowAnalysis:
            return try generateWorkflowCSV(workflowAnalysis)
        default:
            throw AnalysisError.calculationFailed("サポートされていないデータ型です")
        }
    }
    
    private func generateSummaryCSV(_ stats: [String: BuildStatistics]) throws -> String {
        var csv = "期間,総ビルド数,成功数,失敗数,中断数,成功率(%),平均実行時間(分),中央値(分),最小(分),最大(分),P50(分),P75(分),P90(分),P95(分),P99(分),標準偏差(分),総コスト,平均コスト\n"
        
        for (period, stat) in stats {
            let row = [
                escaper.escape(period),
                String(stat.totalBuilds),
                String(stat.successCount),
                String(stat.errorCount),
                String(stat.abortedCount),
                String(format: "%.1f", stat.successRate),
                String(format: "%.2f", stat.averageDuration/60),
                String(format: "%.2f", stat.medianDuration/60),
                String(format: "%.2f", stat.minDuration/60),
                String(format: "%.2f", stat.maxDuration/60),
                String(format: "%.2f", stat.p50Duration/60),
                String(format: "%.2f", stat.p75Duration/60),
                String(format: "%.2f", stat.p90Duration/60),
                String(format: "%.2f", stat.p95Duration/60),
                String(format: "%.2f", stat.p99Duration/60),
                String(format: "%.2f", stat.standardDeviation/60),
                String(stat.totalCreditCost),
                String(format: "%.2f", stat.averageCreditCost)
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func generateRepositoryCSV(_ analysis: RepositoryAnalysis) throws -> String {
        var csv = "リポジトリ,期間,総ビルド数,成功数,失敗数,中断数,成功率(%),平均実行時間(分),中央値(分),最小(分),最大(分),P50(分),P75(分),P90(分),P95(分),P99(分),標準偏差(分),総コスト,平均コスト,主要ワークフロー,失敗率の高いワークフロー\n"
        
        for (repository, periodStats) in analysis.repositoryStats {
            for (period, stats) in periodStats {
                let workflows = analysis.repositoryWorkflows[repository]?.joined(separator: "; ") ?? ""
                let failures = analysis.repositoryFailures[repository]?.joined(separator: "; ") ?? ""
                
                let row = [
                    escaper.escape(repository),
                    escaper.escape(period),
                    String(stats.totalBuilds),
                    String(stats.successCount),
                    String(stats.errorCount),
                    String(stats.abortedCount),
                    String(format: "%.1f", stats.successRate),
                    String(format: "%.2f", stats.averageDuration/60),
                    String(format: "%.2f", stats.medianDuration/60),
                    String(format: "%.2f", stats.minDuration/60),
                    String(format: "%.2f", stats.maxDuration/60),
                    String(format: "%.2f", stats.p50Duration/60),
                    String(format: "%.2f", stats.p75Duration/60),
                    String(format: "%.2f", stats.p90Duration/60),
                    String(format: "%.2f", stats.p95Duration/60),
                    String(format: "%.2f", stats.p99Duration/60),
                    String(format: "%.2f", stats.standardDeviation/60),
                    String(stats.totalCreditCost),
                    String(format: "%.2f", stats.averageCreditCost),
                    escaper.escape(workflows),
                    escaper.escape(failures)
                ].joined(separator: ",")
                
                csv += row + "\n"
            }
        }
        
        return csv
    }
    
    private func generateWorkflowCSV(_ analysis: WorkflowAnalysis) throws -> String {
        var csv = "ワークフロー,実行回数,平均実行時間(分),失敗率(%)\n"
        
        for (workflow, count) in analysis.topWorkflows {
            let longRunning = analysis.longRunningWorkflows.first { $0.0 == workflow }?.1 ?? 0
            let highFailure = analysis.highFailureWorkflows.first { $0.0 == workflow }?.1 ?? 0
            
            let row = [
                escaper.escape(workflow),
                String(count),
                String(format: "%.2f", longRunning/60),
                String(format: "%.1f", highFailure)
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
}
