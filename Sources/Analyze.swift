import ArgumentParser
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

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
        if token == nil {
            token = ProcessInfo.processInfo.environment["BITRISE_ACCESS_TOKEN"]
        }
        if output == nil {
            output = "data.json"
        }
        guard let token, !token.isEmpty else {
            throw AnalyzeError.Parameter("token")
        }
        guard let output, !output.isEmpty else {
            throw AnalyzeError.Parameter("output")
        }
        var paging: Components.Schemas.v0_period_BuildListAllResponseModel.pagingPayload?
        let client = Client(
            serverURL: try Servers.server1(),
            transport: URLSessionTransport(),
            middlewares: [AuthenticationMiddleware(authorizationHeaderFieldValue: token)]
        )
        var data: [Components.Schemas.v0_period_BuildListAllResponseItemModel] = []
        repeat {
            let response = try await client.build_hyphen_list_hyphen_all(.init(query: .init(next: paging?.value1.next)))
            let json = try response.ok.body.json
            if let newData = json.data {
                data += newData
            }
            paging = json.paging
        } while paging?.value1.next != nil
        let result = Components.Schemas.v0_period_BuildListAllResponseModel(data: data, paging: paging)
        try JSONEncoder().encode(result).write(to: URL(filePath: output))
    }
}
