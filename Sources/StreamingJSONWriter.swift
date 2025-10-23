import Foundation

/// ストリーミングJSON出力をサポートするライター
class StreamingJSONWriter {
    private let fileHandle: FileHandle
    private let encoder: JSONEncoder
    private var isFirstItem: Bool = true
    private var isStarted: Bool = false
    
    init(outputPath: String) throws {
        // ファイルを作成して初期化
        let url = URL(filePath: outputPath)
        try "".write(to: url, atomically: true, encoding: .utf8)
        
        self.fileHandle = try FileHandle(forWritingTo: url)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    deinit {
        try? fileHandle.close()
    }
    
    /// JSON出力を開始（配列の開始）
    func startArray() throws {
        guard !isStarted else { return }
        isStarted = true
        try writeString("[\n")
    }
    
    /// アイテムを追加
    func appendItem<T: Codable>(_ item: T) throws {
        if !isFirstItem {
            try writeString(",\n")
        }
        
        let jsonData = try encoder.encode(item)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        try writeString("  \(jsonString)")
        
        isFirstItem = false
    }
    
    /// JSON出力を終了（配列の終了）
    func endArray() throws {
        try writeString("\n]")
        try fileHandle.close()
    }
    
    private func writeString(_ string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw StreamingJSONWriterError.invalidString
        }
        try fileHandle.write(contentsOf: data)
    }
}

enum StreamingJSONWriterError: Error {
    case invalidString
    case fileWriteError
}

/// ビルドデータのストリーミング処理をサポートするプロトコル
protocol StreamingBuildProcessor {
    func processBuildsStreaming(
        outputPath: String,
        progressCallback: @escaping (Int, Int) -> Void
    ) async throws
}

/// ビルドデータのストリーミング処理実装
extension BitriseClient: StreamingBuildProcessor {
    func processBuildsStreaming(
        outputPath: String,
        progressCallback: @escaping (Int, Int) -> Void
    ) async throws {
        let writer = try StreamingJSONWriter(outputPath: outputPath)
        try writer.startArray()
        
        var paging: Components.Schemas.v0_period_BuildListAllResponseModel.pagingPayload?
        var totalProcessed = 0
        var totalCount: Int?
        
        repeat {
            let response = try await fetchBuildsPage(next: paging?.value1.next)
            let json = try response.ok.body.json
            
            if let newData = json.data {
                // 各アイテムをストリーミング出力
                for item in newData {
                    try writer.appendItem(item)
                    totalProcessed += 1
                    
                    // 進捗コールバック
                    if let total = totalCount {
                        progressCallback(totalProcessed, total)
                    }
                }
            }
            
            // 総件数の推定（初回のみ）
            if totalCount == nil {
                // ページサイズから総件数を推定（正確ではないが概算）
                totalCount = 50 // デフォルト値
            }
            
            paging = json.paging
        } while paging?.value1.next != nil
        
        try writer.endArray()
    }
}
