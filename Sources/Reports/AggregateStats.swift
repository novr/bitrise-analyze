import Foundation
import ArgumentParser

struct AggregateStats: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aggregate",
        abstract: "Bitriseビルドデータの集計とレポート生成"
    )
    
    @Option(name: .shortAndLong, help: "データファイルのパス")
    var input: String = "data.json"
    
    @Option(name: .shortAndLong, help: "出力ディレクトリ")
    var output: String = "output"
    
    @Flag(name: .shortAndLong, help: "詳細なログを表示")
    var verbose: Bool = false
    
    @Option(name: .shortAndLong, help: "設定ファイルのパス")
    var config: String?
    
    mutating func run() async throws {
        print("📊 Bitriseデータ集計を開始します...")
        
        // 設定の読み込み
        let analysisConfig = try loadConfiguration()
        
        // 出力ディレクトリを作成
        let outputURL = URL(filePath: output)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        // JSONデータを読み込み
        let data = try Data(contentsOf: URL(filePath: input))
        let builds = try JSONDecoder().decode([BuildData].self, from: data)
        
        if verbose {
            print("📁 読み込み完了: \(builds.count)件のビルドデータ")
        }
        
        // データ処理の実行
        let processor = DataProcessorImpl(config: analysisConfig)
        let processedData = try processor.processBuilds(builds)
        
        // レポート生成
        let reportGenerator = ReportGeneratorImpl(config: analysisConfig)
        try await reportGenerator.generateReports(from: processedData, to: outputURL)
        
        print("✅ 集計完了！出力ディレクトリ: \(output)")
    }
    
    private func loadConfiguration() throws -> AnalysisConfiguration {
        if let configPath = config {
            let configData = try Data(contentsOf: URL(filePath: configPath))
            return try JSONDecoder().decode(AnalysisConfiguration.self, from: configData)
        } else {
            return .default
        }
    }
}

