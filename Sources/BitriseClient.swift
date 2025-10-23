import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Bitrise APIクライアントのプロトコル
protocol BitriseClientProtocol {
    func fetchAllBuilds() async throws -> Components.Schemas.v0_period_BuildListAllResponseModel
}

/// Bitrise APIクライアントの実装
struct BitriseClient: BitriseClientProtocol {
    private let client: Client
    
    init(token: String) throws {
        self.client = Client(
            serverURL: try Servers.Server1.url(),
            transport: URLSessionTransport(),
            middlewares: [AuthenticationMiddleware(authorizationHeaderFieldValue: token)]
        )
    }
    
    func fetchAllBuilds() async throws -> Components.Schemas.v0_period_BuildListAllResponseModel {
        var paging: Components.Schemas.v0_period_BuildListAllResponseModel.pagingPayload?
        var data: [Components.Schemas.v0_period_BuildListAllResponseItemModel] = []
        
        repeat {
            let response = try await client.build_hyphen_list_hyphen_all(.init(query: .init(next: paging?.value1.next)))
            let json = try response.ok.body.json
            if let newData = json.data {
                data += newData
            }
            paging = json.paging
        } while paging?.value1.next != nil
        
        return Components.Schemas.v0_period_BuildListAllResponseModel(data: data, paging: paging)
    }
}
