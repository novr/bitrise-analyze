import Foundation

// MARK: - エラーモデル

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

enum BitriseClientError: Error, LocalizedError, Equatable {
    case invalidToken
    case networkError(String)
    case apiError(String)
    case timeout
    case invalidResponse
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "無効なアクセストークンです。トークンを確認してください。"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .apiError(let message):
            return "APIエラー: \(message)"
        case .timeout:
            return "リクエストがタイムアウトしました。しばらく待ってから再試行してください。"
        case .invalidResponse:
            return "無効なレスポンスを受信しました。"
        case .rateLimited:
            return "APIレート制限に達しました。しばらく待ってから再試行してください。"
        }
    }
}

enum StreamingJSONWriterError: Error {
    case fileCreationFailed
    case writeFailed
    case encodingFailed
    case invalidString
}
