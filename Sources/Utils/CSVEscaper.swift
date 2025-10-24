import Foundation

// MARK: - CSVエスケープ処理

class CSVEscaperImpl: CSVEscaper {
    func escape(_ value: String) -> String {
        // カンマ、ダブルクォート、改行が含まれている場合はエスケープ
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
