import ArgumentParser
import Foundation

/// Bitrise ワークスペースのメンバー一覧をCSV出力するコマンド
struct WorkspaceMembersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace-members",
        abstract: "ワークスペースのメンバー一覧をCSVで出力"
    )
    
    @Argument(help: "ワークスペースのslug（URLの一部）")
    var workspaceSlug: String
    
    @Option(name: .shortAndLong, help: "出力CSVパス（デフォルト: workspace_members.csv）")
    var output: String = "workspace_members.csv"
    
    @Option(name: .shortAndLong, help: "Bitrise APIトークン（未指定時は環境変数 BITRISE_ACCESS_TOKEN）")
    var token: String?
    
    mutating func run() async throws {
        let resolvedToken = token ?? ProcessInfo.processInfo.environment["BITRISE_ACCESS_TOKEN"] ?? ""
        guard !resolvedToken.isEmpty else {
            print("エラー: APIトークンが指定されていません。環境変数 BITRISE_ACCESS_TOKEN を設定するか -t で指定してください。")
            throw ExitCode.failure
        }
        
        print("🔍 ワークスペース '\(workspaceSlug)' のメンバー一覧を取得中...")
        
        let members = try await fetchWorkspaceMembers(workspaceSlug: workspaceSlug, token: resolvedToken)
        
        if members.isEmpty {
            print("⚠️  メンバーが見つかりませんでした。")
            return
        }
        
        try writeCSV(members: members, to: output)
        print("✅ 完了: \(members.count)件のメンバー情報を '\(output)' に出力しました。")
    }
    
    private static let maxPages = 100
    
    private func fetchWorkspaceMembers(workspaceSlug: String, token: String) async throws -> [WorkspaceMemberRow] {
        var allRows: [WorkspaceMemberRow] = []
        var nextCursor: String? = nil
        var page = 0
        
        while page < Self.maxPages {
            page += 1
            var urlString = "https://api.bitrise.io/v0.1/workspaces/\(workspaceSlug)/members"
            if let cursor = nextCursor, let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?next=\(encoded)"
            }
            guard let url = URL(string: urlString) else { break }
            
            var request = URLRequest(url: url)
            request.setValue(token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { break }
            
            switch http.statusCode {
            case 401:
                print("エラー: 認証に失敗しました。トークンを確認してください。")
                throw ExitCode.failure
            case 403:
                print("エラー: このワークスペースへのアクセス権限がありません。")
                throw ExitCode.failure
            case 404:
                print("エラー: ワークスペース '\(workspaceSlug)' が見つかりません。")
                throw ExitCode.failure
            case 200:
                break
            default:
                print("エラー: API呼び出しに失敗しました (HTTP \(http.statusCode))")
                throw ExitCode.failure
            }
            
            let decoded: WorkspaceMembersResponse
            do {
                decoded = try JSONDecoder().decode(WorkspaceMembersResponse.self, from: data)
            } catch {
                print("エラー: レスポンス形式が想定と異なります (\(error.localizedDescription))")
                throw ExitCode.failure
            }
            let items = decoded.data ?? []
            let rows = items.map { member in
                WorkspaceMemberRow(
                    email: member.user?.email ?? "",
                    username: member.user?.username ?? "",
                    slug: member.user?.slug ?? "",
                    role: member.role ?? "",
                    joined_at: member.joined_at ?? ""
                )
            }
            allRows.append(contentsOf: rows)
            print("📄 ページ \(page) 完了: \(rows.count)件取得 (累計: \(allRows.count)件)")
            
            nextCursor = decoded.paging?.next
            if nextCursor == nil { break }
        }
        if page >= Self.maxPages && nextCursor != nil {
            print("⚠️  最大 \(Self.maxPages) ページで打ち切りました。")
        }
        return allRows
    }
    
    private func writeCSV(members: [WorkspaceMemberRow], to path: String) throws {
        let header = "email,username,slug,role,joined_at"
        func escape(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        let lines = [header] + members.map { m in
            [escape(m.email), escape(m.username), escape(m.slug), escape(m.role), escape(m.joined_at)].joined(separator: ",")
        }
        let csv = lines.joined(separator: "\n")
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent().path
        if !dir.isEmpty && dir != "." {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct WorkspaceMemberRow {
    let email: String
    let username: String
    let slug: String
    let role: String
    let joined_at: String
}

private struct WorkspaceMembersResponse: Decodable {
    let data: [WorkspaceMemberDTO]?
    let paging: Paging?
    struct Paging: Decodable { let next: String? }
}

private struct WorkspaceMemberDTO: Decodable {
    let user: User?
    let role: String?
    let joined_at: String?
    struct User: Decodable {
        let email: String?
        let username: String?
        let slug: String?
    }
}
