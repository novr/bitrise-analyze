import Foundation

// MARK: - ビルドデータモデル

struct BuildData: Codable {
    let branch: String?
    let buildNumber: Int?
    let commitHash: String?
    let commitMessage: String?
    let commitViewUrl: String?
    let creditCost: Int?
    let environmentPrepareFinishedAt: String?
    let finishedAt: String?
    let isOnHold: Bool?
    let isProcessed: Bool?
    let machineTypeId: String?
    let pullRequestId: Int?
    let pullRequestTargetBranch: String?
    let pullRequestViewUrl: String?
    let repository: Repository?
    let slug: String?
    let stackIdentifier: String?
    let startedOnWorkerAt: String?
    let status: Int?
    let statusText: String?
    let triggeredAt: String?
    let triggeredBy: String?
    let triggeredWorkflow: String?
    
    enum CodingKeys: String, CodingKey {
        case branch
        case buildNumber = "build_number"
        case commitHash = "commit_hash"
        case commitMessage = "commit_message"
        case commitViewUrl = "commit_view_url"
        case creditCost = "credit_cost"
        case environmentPrepareFinishedAt = "environment_prepare_finished_at"
        case finishedAt = "finished_at"
        case isOnHold = "is_on_hold"
        case isProcessed = "is_processed"
        case machineTypeId = "machine_type_id"
        case pullRequestId = "pull_request_id"
        case pullRequestTargetBranch = "pull_request_target_branch"
        case pullRequestViewUrl = "pull_request_view_url"
        case repository
        case slug
        case stackIdentifier = "stack_identifier"
        case startedOnWorkerAt = "started_on_worker_at"
        case status
        case statusText = "status_text"
        case triggeredAt = "triggered_at"
        case triggeredBy = "triggered_by"
        case triggeredWorkflow = "triggered_workflow"
    }
}

struct Repository: Codable {
    let isDisabled: Bool?
    let isGithubChecksEnabled: Bool?
    let isPublic: Bool?
    let owner: Owner?
    let projectType: String?
    let provider: String?
    let repoOwner: String?
    let repoSlug: String?
    let repoUrl: String?
    let slug: String?
    let status: Int?
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case isDisabled = "is_disabled"
        case isGithubChecksEnabled = "is_github_checks_enabled"
        case isPublic = "is_public"
        case owner
        case projectType = "project_type"
        case provider
        case repoOwner = "repo_owner"
        case repoSlug = "repo_slug"
        case repoUrl = "repo_url"
        case slug
        case status
        case title
    }
}

struct Owner: Codable {
    let accountType: String?
    let name: String?
    let slug: String?
    
    enum CodingKeys: String, CodingKey {
        case accountType = "account_type"
        case name
        case slug
    }
}
