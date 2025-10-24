import Foundation

// MARK: - 統計データモデル

struct BuildStatistics {
    let period: String
    let totalBuilds: Int
    let successCount: Int
    let errorCount: Int
    let abortedCount: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let medianDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let p50Duration: TimeInterval
    let p75Duration: TimeInterval
    let p90Duration: TimeInterval
    let p95Duration: TimeInterval
    let p99Duration: TimeInterval
    let standardDeviation: TimeInterval
    let totalCreditCost: Int
    let averageCreditCost: Double
}

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
