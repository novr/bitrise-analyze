import Foundation

// MARK: - 設定データモデル

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
