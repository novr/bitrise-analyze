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
}
