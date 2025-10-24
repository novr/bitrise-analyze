import Foundation

// MARK: - エラー定義

enum AnalysisError: Error, LocalizedError {
    case invalidData(String)
    case calculationFailed(String)
    case outputFailed(String)
    case invalidDateCalculation
    case fileNotFound(String)
    case encodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "無効なデータ: \(message)"
        case .calculationFailed(let message):
            return "計算エラー: \(message)"
        case .outputFailed(let message):
            return "出力エラー: \(message)"
        case .invalidDateCalculation:
            return "日付計算エラー"
        case .fileNotFound(let path):
            return "ファイルが見つかりません: \(path)"
        case .encodingFailed(let message):
            return "エンコーディングエラー: \(message)"
        }
    }
}

// MARK: - 設定構造体

struct AnalysisConfiguration: Codable {
    let periods: [AnalysisPeriod]
    let thresholds: AnalysisThresholds
    let outputFormats: [OutputFormat]
    let performance: PerformanceSettings
    
    static let `default` = AnalysisConfiguration(
        periods: [
            AnalysisPeriod(name: "7日", days: 7),
            AnalysisPeriod(name: "30日", days: 30),
            AnalysisPeriod(name: "90日", days: 90),
            AnalysisPeriod(name: "全期間", days: nil)
        ],
        thresholds: AnalysisThresholds(
            minWorkflowExecutions: 5,
            minFailureRate: 50.0,
            topWorkflowCount: 3,
            maxDurationHours: 24,
            minDurationSeconds: 0
        ),
        outputFormats: [.csv, .markdown],
        performance: PerformanceSettings(
            batchSize: 1000,
            enableParallelProcessing: true,
            maxMemoryUsageMB: 512
        )
    )
}

struct AnalysisPeriod: Codable {
    let name: String
    let days: Int?
}

struct AnalysisThresholds: Codable {
    let minWorkflowExecutions: Int
    let minFailureRate: Double
    let topWorkflowCount: Int
    let maxDurationHours: Int
    let minDurationSeconds: Int
}

enum OutputFormat: String, Codable, CaseIterable {
    case csv = "csv"
    case markdown = "markdown"
    case json = "json"
}

struct PerformanceSettings: Codable {
    let batchSize: Int
    let enableParallelProcessing: Bool
    let maxMemoryUsageMB: Int
}

// MARK: - 統計計算プロトコル

protocol StatisticsCalculator {
    func calculate(for builds: [BuildData], period: String) throws -> BuildStatistics
}

protocol WorkflowAnalyzer {
    func analyzeWorkflows(for builds: [BuildData]) throws -> WorkflowAnalysis
}

protocol RepositoryAnalyzer {
    func analyzeRepositories(for builds: [BuildData], periods: [AnalysisPeriod]) throws -> RepositoryAnalysis
}

// MARK: - レポート生成プロトコル

protocol ReportGenerator {
    func generate(from stats: BuildStatistics, period: String) throws -> String
}

protocol CSVGenerator {
    func generateCSV(from data: Any) throws -> String
}

protocol MarkdownGenerator {
    func generateMarkdown(from data: Any) throws -> String
}

// MARK: - データ処理プロトコル

protocol DataProcessor {
    func processBuilds(_ builds: [BuildData]) throws -> ProcessedData
}

protocol DataValidator {
    func validate(_ builds: [BuildData]) throws -> [BuildData]
}

// MARK: - 出力プロトコル

protocol OutputManager {
    func writeReports(_ reports: [Report], to directory: URL) throws
    func writeCSV(_ csv: String, filename: String, to directory: URL) throws
    func writeMarkdown(_ markdown: String, filename: String, to directory: URL) throws
}

// MARK: - ユーティリティプロトコル

protocol DateFormatterProvider {
    var iso8601Formatter: ISO8601DateFormatter { get }
    var displayFormatter: DateFormatter { get }
}

protocol CSVEscaper {
    func escape(_ value: String) -> String
}

// MARK: - 統計データ構造（拡張）

struct WorkflowAnalysis {
    let topWorkflows: [(String, Int)]
    let longRunningWorkflows: [(String, TimeInterval)]
    let highFailureWorkflows: [(String, Double)]
}

struct RepositoryAnalysis {
    let repositoryStats: [String: [String: BuildStatistics]]
    let repositoryWorkflows: [String: [String]]
    let repositoryFailures: [String: [String]]
}

struct ProcessedData {
    let builds: [BuildData]
    let statistics: [String: BuildStatistics]
    let workflowAnalysis: WorkflowAnalysis
    let repositoryAnalysis: RepositoryAnalysis
}

struct Report {
    let filename: String
    let content: String
    let format: OutputFormat
}
