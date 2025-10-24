import Foundation

// MARK: - エラー定義と設定構造体はModelsディレクトリに移動済み

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

// MARK: - 統計データ構造はModelsディレクトリに移動済み
