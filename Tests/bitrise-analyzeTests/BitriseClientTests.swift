import XCTest
import OpenAPIRuntime
@testable import bitrise_analyze

final class BitriseClientTests: XCTestCase {
    
    func testFetchAllBuildsSuccess() async throws {
        // Given
        let mockClient = MockBitriseClient(shouldThrowError: false)
        
        // When
        let result = try await mockClient.fetchAllBuilds()
        
        // Then
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?.count, 0)
        XCTAssertNil(result.paging)
    }
    
    func testFetchAllBuildsWithError() async {
        // Given
        let mockClient = MockBitriseClient(shouldThrowError: true)
        
        // When & Then
        do {
            _ = try await mockClient.fetchAllBuilds()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NSError)
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "MockError")
            XCTAssertEqual(nsError.code, 1)
        }
    }
    
    func testMockClientInitialization() {
        // Given & When
        let mockClient = MockBitriseClient()
        
        // Then
        XCTAssertNotNil(mockClient)
    }
    
    func testBitriseClientErrorDescriptions() {
        // Given & When
        let invalidTokenError = BitriseClientError.invalidToken
        let networkError = BitriseClientError.networkError("Test network error")
        let apiError = BitriseClientError.apiError("Test API Error")
        let timeoutError = BitriseClientError.timeout
        let invalidResponseError = BitriseClientError.invalidResponse
        let rateLimitedError = BitriseClientError.rateLimited
        
        // Then
        XCTAssertNotNil(invalidTokenError.errorDescription)
        XCTAssertTrue(invalidTokenError.errorDescription!.contains("無効なアクセストークン"))
        
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("ネットワークエラー"))
        
        XCTAssertNotNil(apiError.errorDescription)
        XCTAssertTrue(apiError.errorDescription!.contains("APIエラー"))
        
        XCTAssertNotNil(timeoutError.errorDescription)
        XCTAssertTrue(timeoutError.errorDescription!.contains("タイムアウト"))
        
        XCTAssertNotNil(invalidResponseError.errorDescription)
        XCTAssertTrue(invalidResponseError.errorDescription!.contains("無効なレスポンス"))
        
        XCTAssertNotNil(rateLimitedError.errorDescription)
        XCTAssertTrue(rateLimitedError.errorDescription!.contains("レート制限"))
    }
    
    func testBitriseClientInitializationWithEmptyToken() {
        // Given & When & Then
        XCTAssertThrowsError(try BitriseClient(token: "")) { error in
            XCTAssertTrue(error is BitriseClientError)
            if let bitriseError = error as? BitriseClientError {
                XCTAssertEqual(bitriseError, .invalidToken)
            }
        }
    }
    
    func testBitriseClientInitializationWithValidToken() throws {
        // Given
        let token = "valid-token"
        
        // When
        let client = try BitriseClient(token: token)
        
        // Then
        XCTAssertNotNil(client)
    }
}
