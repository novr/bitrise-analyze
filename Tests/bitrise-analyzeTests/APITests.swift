import XCTest
@testable import bitrise_analyze

class APITests: XCTestCase {
    
    // MARK: - BitriseClient Tests
    
    func testBitriseClientInitializationWithValidToken() throws {
        let client = try BitriseClient(token: "valid-token")
        XCTAssertNotNil(client)
    }
    
    func testBitriseClientInitializationWithEmptyToken() {
        XCTAssertThrowsError(try BitriseClient(token: "")) { error in
            XCTAssertTrue(error is BitriseClientError)
            if let bitriseError = error as? BitriseClientError {
                XCTAssertEqual(bitriseError, .invalidToken)
            }
        }
    }
    
    func testBitriseClientErrorEquality() {
        let error1 = BitriseClientError.invalidToken
        let error2 = BitriseClientError.invalidToken
        let error3 = BitriseClientError.networkError("test")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    // MARK: - AuthenticationMiddleware Tests
    
    func testAuthenticationMiddlewareInitialization() {
        let middleware = AuthenticationMiddleware(authorizationHeaderFieldValue: "test-token")
        XCTAssertNotNil(middleware)
    }
    
    // MARK: - CurlMiddleware Tests
    
    func testCurlMiddlewareInitialization() {
        let middleware = CurlMiddleware()
        XCTAssertNotNil(middleware)
    }
    
    // MARK: - StreamingJSONWriter Tests
    
    func testStreamingJSONWriterInitialization() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.json")
        let writer = try StreamingJSONWriter(outputPath: tempURL.path)
        XCTAssertNotNil(writer)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testStreamingJSONWriterErrorCases() {
        let invalidStringError = StreamingJSONWriterError.invalidString
        let encodingError = StreamingJSONWriterError.encodingFailed
        let fileCreationError = StreamingJSONWriterError.fileCreationFailed
        
        XCTAssertNotNil(invalidStringError)
        XCTAssertNotNil(encodingError)
        XCTAssertNotNil(fileCreationError)
    }
    
    // MARK: - StreamingJSONWriter Integration Tests
    
    func testStreamingJSONWriterFullWorkflow() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_streaming.json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let writer = try StreamingJSONWriter(outputPath: tempURL.path)
        
        // Start array
        try writer.startArray()
        
        // Add items
        let testData = ["item1", "item2", "item3"]
        for item in testData {
            try writer.appendItem(item)
        }
        
        // End array
        try writer.endArray()
        
        // Verify file was created and contains expected content
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("item1"))
        XCTAssertTrue(content.contains("item2"))
        XCTAssertTrue(content.contains("item3"))
    }
    
    // MARK: - Mock Tests
    
    func testMockBitriseClient() {
        let mockClient = MockBitriseClient()
        XCTAssertNotNil(mockClient)
    }
    
    // MARK: - Error Handling Tests
    
    func testBitriseClientErrorDescriptions() {
        let errors: [BitriseClientError] = [
            .invalidToken,
            .networkError("Network issue"),
            .apiError("API issue"),
            .timeout,
            .invalidResponse,
            .rateLimited
        ]
        
        for error in errors {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty)
            // 日本語のエラーメッセージが含まれていることを確認
            XCTAssertTrue(description.contains("エラー") || description.contains("無効") || description.contains("ネットワーク") || description.contains("API") || description.contains("タイムアウト") || description.contains("レスポンス") || description.contains("レート"))
        }
    }
    
    // MARK: - Performance Tests
    
    func testStreamingJSONWriterPerformance() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("performance_test.json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        measure {
            do {
                let writer = try StreamingJSONWriter(outputPath: tempURL.path)
                try writer.startArray()
                
                for i in 0..<1000 {
                    try writer.appendItem(["id": String(i), "data": "test\(i)"])
                }
                
                try writer.endArray()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}
