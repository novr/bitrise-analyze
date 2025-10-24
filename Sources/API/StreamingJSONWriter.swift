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
        var pageCount = 0
        let startTime = Date()
        
        repeat {
            pageCount += 1
            let response = try await fetchBuildsPage(next: paging?.value1.next)
            let json = try response.ok.body.json
            
            if let newData = json.data {
                print("📄 ページ \(pageCount) 処理中: \(newData.count)件")
                
                // 各アイテムをストリーミング出力
                for (index, item) in newData.enumerated() {
                    try writer.appendItem(item)
                    totalProcessed += 1
                    
                    // 進捗コールバック（総件数は不明なので処理済み件数のみ表示）
                    progressCallback(totalProcessed, 0)
                    
                    // ページ内の進捗表示（10件ごと）
                    if (index + 1) % 10 == 0 || index == newData.count - 1 {
                        let elapsed = Date().timeIntervalSince(startTime)
                        let rate = Double(totalProcessed) / elapsed
                        print("  📊 ページ内進捗: \(index + 1)/\(newData.count)件 (処理速度: \(String(format: "%.1f", rate))件/秒)")
                    }
                }
                
                print("✅ ページ \(pageCount) 完了: \(newData.count)件処理 (累計: \(totalProcessed)件)")
            }
            
            paging = json.paging
        } while paging?.value1.next != nil
        
        try writer.endArray()
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("🎉 全処理完了: \(totalProcessed)件を\(String(format: "%.1f", totalTime))秒で処理")
    }
}
