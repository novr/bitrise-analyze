//
//  AuthenticationMiddleware.swift
//
//
//  Created by 古宮 伸久 on 2024/01/18.
//

import OpenAPIRuntime
import Foundation
import HTTPTypes

/// A client middleware that injects a value into the `Authorization` header field of the request.
package struct AuthenticationMiddleware {

    /// The value for the `Authorization` header field.
    private let value: String

    /// Creates a new middleware.
    /// - Parameter value: The value for the `Authorization` header field.
    package init(authorizationHeaderFieldValue value: String) { self.value = value }
}

extension AuthenticationMiddleware: ClientMiddleware {
    package func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        // Adds the `Authorization` header field with the provided value.
        request.headerFields[.authorization] = value
        return try await next(request, body, baseURL)
    }
}
