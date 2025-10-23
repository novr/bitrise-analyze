import Foundation
import OpenAPIRuntime
@testable import bitrise_analyze

/// テスト用のモックBitriseClient
struct MockBitriseClient: BitriseClientProtocol {
    private let shouldThrowError: Bool
    
    init(shouldThrowError: Bool = false) {
        self.shouldThrowError = shouldThrowError
    }
    
    func fetchAllBuilds() async throws -> Components.Schemas.v0_period_BuildListAllResponseModel {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock network error"])
        }
        
        // シンプルなモックデータを返す
        return Components.Schemas.v0_period_BuildListAllResponseModel(
            data: [],
            paging: nil
        )
    }
}
