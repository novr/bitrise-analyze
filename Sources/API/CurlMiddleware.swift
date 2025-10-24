import Foundation
import HTTPTypes
import OpenAPIRuntime

final class CurlMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var baseCommand = ""
        if let query = baseURL.query() {
            baseCommand = #"curl "\#(baseURL.absoluteString)\#(request.path!)"?\#(query)""#
        } else {
            baseCommand = #"curl "\#(baseURL.absoluteString)\#(request.path!)""#
        }

        if request.method == .head {
            baseCommand += " --head"
        }

        var command = [baseCommand]

        if request.method != .get && request.method != .head {
            command.append("-X \(request.method.rawValue)")
        }

        for field in request.headerFields {
            if field.name != .cookie {
                command.append("-H '\(field.name): \(field.value)'")
            }
        }

        print(command.joined(separator: " \\\n\t"))

        return try await next(request, body, baseURL)
    }
}
