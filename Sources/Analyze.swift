import ArgumentParser
import Foundation
import OpenAPIRuntime

@main
struct Analyze: AsyncParsableCommand {
    enum AnalyzeError: Error {
        case Parameter(String)
    }

    @Option
    var token: String?

    @Option
    var output: String?

    mutating func run() async throws {
        do {
            // パラメータの設定と検証
            let token = try getToken()
            let output = getOutput()
            
            print("Bitrise APIからビルドデータを取得中...")
            
            // BitriseClientを使用してデータを取得
            let bitriseClient = try BitriseClient(token: token)
            let result = try await bitriseClient.fetchAllBuilds()
            
            // 結果をファイルに出力
            let jsonData = try JSONEncoder().encode(result)
            try jsonData.write(to: URL(filePath: output))
            
            print("✅ データの取得が完了しました。")
            print("📁 出力ファイル: \(output)")
            print("📊 取得件数: \(result.data?.count ?? 0)件")
            
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
