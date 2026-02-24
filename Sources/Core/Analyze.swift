import ArgumentParser
import Foundation
import OpenAPIRuntime

@main
struct Analyze: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bitrise-analyze",
        abstract: "Bitriseビルドデータの取得と分析ツール",
        subcommands: [Aggregate.self, WorkspaceMembersCommand.self]
    )
    
    enum AnalyzeError: Error {
        case Parameter(String)
    }

    @Option
    var token: String?

    @Option
    var output: String?
    
    @Flag
    var streaming: Bool = false

    mutating func run() async throws {
        do {
            // パラメータの設定と検証
            let token = try getToken()
            let output = getOutput()
            
            print("Bitrise APIからビルドデータを取得中...")
            
            // BitriseClientを使用してデータを取得
            let bitriseClient = try BitriseClient(token: token)
            
            if streaming {
                print("🔄 ストリーミングモードで処理中...")
                try await bitriseClient.processBuildsStreaming(
                    outputPath: output,
                    progressCallback: { processed, total in
                        if total > 0 {
                            print("📊 処理済み: \(processed)件 / \(total)件")
                        } else {
                            print("📊 処理済み: \(processed)件")
                        }
                    }
                )
                print("✅ ストリーミング処理が完了しました。")
            } else {
                print("📥 従来モードでデータ取得中...")
                let result = try await bitriseClient.fetchAllBuilds()
                
                // 結果をファイルに出力
                print("💾 ファイルに出力中...")
                let jsonData = try JSONEncoder().encode(result)
                try jsonData.write(to: URL(filePath: output))
                
                print("✅ データの取得が完了しました。")
                print("📊 取得件数: \(result.data?.count ?? 0)件")
            }
            
            print("📁 出力ファイル: \(output)")
            
        } catch let error as BitriseClientError {
            print("❌ エラーが発生しました: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("❌ 予期しないエラーが発生しました: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func getToken() throws -> String {
        if let token = token, !token.isEmpty {
            return token
        }
        if let envToken = ProcessInfo.processInfo.environment["BITRISE_ACCESS_TOKEN"], !envToken.isEmpty {
            return envToken
        }
        throw AnalyzeError.Parameter("token")
    }
    
    private func getOutput() -> String {
        return output ?? "data.json"
    }
}
