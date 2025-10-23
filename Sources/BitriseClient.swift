import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Bitrise APIクライアントのエラー型
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

/// Bitrise APIクライアントのプロトコル
protocol BitriseClientProtocol {
    func fetchAllBuilds() async throws -> Components.Schemas.v0_period_BuildListAllResponseModel
}

/// Bitrise APIクライアントの実装
struct BitriseClient: BitriseClientProtocol {
    private let client: Client
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    init(token: String, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) throws {
        guard !token.isEmpty else {
            throw BitriseClientError.invalidToken
        }
        
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        
        self.client = Client(
            serverURL: try Servers.Server1.url(),
            transport: URLSessionTransport(),
            middlewares: [AuthenticationMiddleware(authorizationHeaderFieldValue: token)]
        )
    }
    
    func fetchAllBuilds() async throws -> Components.Schemas.v0_period_BuildListAllResponseModel {
        var paging: Components.Schemas.v0_period_BuildListAllResponseModel.pagingPayload?
        var data: [Components.Schemas.v0_period_BuildListAllResponseItemModel] = []
        var pageCount = 0
        var totalProcessed = 0
        
        repeat {
            pageCount += 1
            let response = try await fetchBuildsPage(next: paging?.value1.next)
            let json = try response.ok.body.json
            
            if let newData = json.data {
                data += newData
                totalProcessed += newData.count
                print("📄 ページ \(pageCount) 完了: \(newData.count)件取得 (累計: \(totalProcessed)件)")
            }
            
            paging = json.paging
        } while paging?.value1.next != nil
        
        return Components.Schemas.v0_period_BuildListAllResponseModel(data: data, paging: paging)
    }
    
    func fetchBuildsPage(next: String?) async throws -> Operations.build_hyphen_list_hyphen_all.Output {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let response = try await client.build_hyphen_list_hyphen_all(.init(query: .init(next: next)))
                
                // レスポンスの検証
                switch response {
                case .ok:
                    return response
                case .unauthorized:
                    throw BitriseClientError.invalidToken
                case .badRequest, .notFound, .internalServerError:
                    throw BitriseClientError.apiError("APIエラーが発生しました")
                case .undocumented(let statusCode, _):
                    if statusCode == 429 {
                        throw BitriseClientError.rateLimited
                    } else {
                        throw BitriseClientError.apiError("APIエラー (HTTP \(statusCode))")
                    }
                }
            } catch let error as BitriseClientError {
                // リトライしないエラー
                throw error
            } catch {
                lastError = error
                
                // 最後の試行でない場合は待機
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt + 1) * 1_000_000_000))
                }
            }
        }
        
        // 全てのリトライが失敗した場合
        if let lastError = lastError {
            if let urlError = lastError as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw BitriseClientError.timeout
                case .notConnectedToInternet, .networkConnectionLost:
                    throw BitriseClientError.networkError(urlError.localizedDescription)
                default:
                    throw BitriseClientError.networkError(urlError.localizedDescription)
                }
            } else {
                throw BitriseClientError.networkError(lastError.localizedDescription)
            }
        } else {
            throw BitriseClientError.invalidResponse
        }
    }
}
