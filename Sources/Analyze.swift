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
        // パラメータの設定と検証
        let token = getToken()
        let output = getOutput()
        
        // BitriseClientを使用してデータを取得
        let bitriseClient = try BitriseClient(token: token)
        let result = try await bitriseClient.fetchAllBuilds()
        
        // 結果をファイルに出力
        try JSONEncoder().encode(result).write(to: URL(filePath: output))
    }
    
    private func getToken() -> String {
        if let token = token, !token.isEmpty {
            return token
        }
        if let envToken = ProcessInfo.processInfo.environment["BITRISE_ACCESS_TOKEN"], !envToken.isEmpty {
            return envToken
        }
        fatalError("Token is required")
    }
    
    private func getOutput() -> String {
        return output ?? "data.json"
    }
}
