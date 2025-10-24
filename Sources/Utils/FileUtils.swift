import Foundation

// MARK: - ファイル操作ユーティリティ

/// レポートをファイルに書き込む
func writeReports(_ reports: [Report], to directory: URL) throws {
    try createDirectoryIfNeeded(directory)
    
    for report in reports {
        let fileURL = directory.appendingPathComponent(report.filename)
        try report.content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

/// CSVファイルを書き込む（Excel対応のためUTF-8 BOM付き）
func writeCSV(_ csv: String, filename: String, to directory: URL) throws {
    try createDirectoryIfNeeded(directory)
    
    let fileURL = directory.appendingPathComponent(filename)
    
    // UTF-8 BOMを追加してExcelでの文字化けを防ぐ
    let bom = "\u{FEFF}"
    let csvWithBom = bom + csv
    
    try csvWithBom.write(to: fileURL, atomically: true, encoding: .utf8)
}

/// Markdownファイルを書き込む
func writeMarkdown(_ markdown: String, filename: String, to directory: URL) throws {
    try createDirectoryIfNeeded(directory)
    
    let fileURL = directory.appendingPathComponent(filename)
    try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
}

/// ディレクトリが存在しない場合は作成する
private func createDirectoryIfNeeded(_ directory: URL) throws {
    if !FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

/// ファイルが存在するかチェックする
func fileExists(at path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

/// ファイルサイズを取得する
func getFileSize(at path: String) -> Int64? {
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return attributes[.size] as? Int64
    } catch {
        return nil
    }
}

/// ディレクトリ内のファイル一覧を取得する
func listFiles(in directory: URL) throws -> [String] {
    return try FileManager.default.contentsOfDirectory(atPath: directory.path)
}

/// ファイルを削除する
func deleteFile(at path: String) throws {
    try FileManager.default.removeItem(atPath: path)
}

/// ディレクトリを削除する
func deleteDirectory(at path: String) throws {
    try FileManager.default.removeItem(atPath: path)
}
