import Foundation

// MARK: - 出力マネージャー

class OutputManagerImpl: OutputManager {
    private let fileManager = FileManager.default
    
    func writeReports(_ reports: [Report], to directory: URL) throws {
        try createDirectoryIfNeeded(directory)
        
        for report in reports {
            let fileURL = directory.appendingPathComponent(report.filename)
            try report.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func writeCSV(_ csv: String, filename: String, to directory: URL) throws {
        try createDirectoryIfNeeded(directory)
        let fileURL = directory.appendingPathComponent(filename)
        
        // UTF-8 BOMを追加してExcelでの文字化けを防ぐ
        let bom = "\u{FEFF}"
        let csvWithBom = bom + csv
        
        try csvWithBom.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func writeMarkdown(_ markdown: String, filename: String, to directory: URL) throws {
        try createDirectoryIfNeeded(directory)
        let fileURL = directory.appendingPathComponent(filename)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func createDirectoryIfNeeded(_ directory: URL) throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
