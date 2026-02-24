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
    
    func generateProjectSummaryCSV(from analysis: RepositoryAnalysis) throws -> String {
        typealias PeriodSums = (builds: Int, totalMin: Double)
        var byProject: [String: (d30: PeriodSums, d90: PeriodSums)] = [:]
        for repository in analysis.repositoryStats.keys {
            guard let periodStats = analysis.repositoryStats[repository] else { continue }
            let project = CostEstimator.projectName(from: repository)
            func rowFor(_ period: String) -> PeriodSums {
                guard let stats = periodStats[period] else { return (0, 0) }
                let avgMin = stats.averageDuration / 60
                let totalMin = Double(stats.totalBuilds) * avgMin
                return (stats.totalBuilds, totalMin)
            }
            let d30 = rowFor("30日")
            let d90 = rowFor("90日")
            let cur = byProject[project] ?? ((0, 0), (0, 0))
            byProject[project] = (
                (cur.d30.builds + d30.builds, cur.d30.totalMin + d30.totalMin),
                (cur.d90.builds + d90.builds, cur.d90.totalMin + d90.totalMin)
            )
        }
        var csv = "リポジトリ(プロジェクト),30日_ビルド数,30日_平均時間_分,30日_総時間_分,90日_ビルド数,90日_平均時間_分,90日_総時間_分\n"
        for project in byProject.keys.sorted() {
            let (d30, d90) = byProject[project]!
            if d30.builds == 0 && d90.builds == 0 { continue }
            let avg30 = d30.builds > 0 ? d30.totalMin / Double(d30.builds) : 0.0
            let avg90 = d90.builds > 0 ? d90.totalMin / Double(d90.builds) : 0.0
            let line = [
                escaper.escape(project),
                String(d30.builds),
                String(format: "%.2f", avg30),
                String(format: "%.2f", d30.totalMin),
                String(d90.builds),
                String(format: "%.2f", avg90),
                String(format: "%.2f", d90.totalMin)
            ].joined(separator: ",")
            csv += line + "\n"
        }
        return csv
    }
    
    func generateCostEstimateCSV(from analysis: RepositoryAnalysis, period: String) throws -> String {
        guard period == "30日" || period == "90日" else { return "" }
        typealias ProjectSums = (iosBuilds: Int, iosHours: Double, androidBuilds: Int, androidHours: Double, otherBuilds: Int, otherHours: Double)
        var byProject: [String: ProjectSums] = [:]
        for repository in analysis.repositoryStats.keys {
            guard let periodStats = analysis.repositoryStats[repository], let stats = periodStats[period] else { continue }
            let builds = stats.totalBuilds
            let avgMin = stats.averageDuration / 60
            let totalMin = Double(builds) * avgMin
            let hours = totalMin / 60
            let project = CostEstimator.projectName(from: repository)
            var iosBuilds = 0, androidBuilds = 0, otherBuilds = 0
            var iosHours = 0.0, androidHours = 0.0, otherHours = 0.0
            if CostEstimator.isIOSRepo(repository) {
                iosBuilds = builds
                iosHours = hours
            } else if CostEstimator.isAndroidRepo(repository) {
                androidBuilds = builds
                androidHours = hours
            } else {
                otherBuilds = builds
                otherHours = hours
            }
            let cur = byProject[project] ?? (0, 0, 0, 0, 0, 0)
            byProject[project] = (
                cur.iosBuilds + iosBuilds, cur.iosHours + iosHours,
                cur.androidBuilds + androidBuilds, cur.androidHours + androidHours,
                cur.otherBuilds + otherBuilds, cur.otherHours + otherHours
            )
        }
        var csv = "リポジトリ(プロジェクト),iOSビルド数,iOS使用時間(時間),Androidビルド数,Android使用時間(時間),その他ビルド数,その他使用時間(時間),合計ビルド数,合計使用時間(時間),ケース1_Xcode+Bitrise(USD),ケース1_Xcodeプラン,ケース1_Bitriseプラン,ケース2_Xcode+GitHub(USD),ケース3_Bitrise(USD),ケース3_Bitriseプラン,ケース4_GitHub(USD)\n"
        for project in byProject.keys.sorted() {
            let s = byProject[project]!
            let totalBuilds = s.iosBuilds + s.androidBuilds + s.otherBuilds
            let totalHours = s.iosHours + s.androidHours + s.otherHours
            let hasIOS = s.iosBuilds > 0
            let hasAndroid = s.androidBuilds > 0
            let costs = CostEstimator.calculateCaseCosts(
                iosHours: s.iosHours, androidHours: s.androidHours,
                iosBuilds: s.iosBuilds, androidBuilds: s.androidBuilds,
                otherHours: s.otherHours, otherBuilds: s.otherBuilds,
                hasIOS: hasIOS, hasAndroid: hasAndroid
            )
            let line = [
                escaper.escape(project),
                String(s.iosBuilds),
                String(format: "%.2f", s.iosHours),
                String(s.androidBuilds),
                String(format: "%.2f", s.androidHours),
                String(s.otherBuilds),
                String(format: "%.2f", s.otherHours),
                String(totalBuilds),
                String(format: "%.2f", totalHours),
                String(format: "%.2f", costs.case1XcodeBitrise),
                escaper.escape(costs.case1XcodePlanName),
                escaper.escape(costs.case1BitrisePlanName),
                String(format: "%.2f", costs.case2XcodeGitHub),
                String(format: "%.2f", costs.case3Bitrise),
                escaper.escape(costs.case3BitrisePlanName),
                String(format: "%.2f", costs.case4GitHub)
            ].joined(separator: ",")
            csv += line + "\n"
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
