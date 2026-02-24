import Foundation

// MARK: - コスト推測（Xcode Cloud / Bitrise / GitHub Actions）
// 料金・プランは公式情報に基づく。要定期確認。

struct XcodePlan {
    let name: String
    let cost: Double
    let hours: Double
}

struct BitrisePlan {
    let name: String
    let cost: Double
    let builds: Int
}

enum CostEstimator {
    static let githubRates: (macos: Double, linux2core: Double, linux8coreArm64: Double) = (0.08, 0.008, 0.02)
    
    static let xcodePlans: [XcodePlan] = [
        XcodePlan(name: "ADP付属", cost: 0, hours: 25),
        XcodePlan(name: "tier1", cost: 49.99, hours: 100),
        XcodePlan(name: "tier2", cost: 99.99, hours: 250),
        XcodePlan(name: "tier3", cost: 399.99, hours: 1000),
        XcodePlan(name: "tier4", cost: 3999.99, hours: 10000),
    ]
    
    static let bitrisePlans: [BitrisePlan] = [
        BitrisePlan(name: "Hobby", cost: 0, builds: 0),
        BitrisePlan(name: "Starter tier1", cost: 99, builds: 100),
        BitrisePlan(name: "Starter tier2", cost: 199, builds: 100),
        BitrisePlan(name: "Starter tier3", cost: 299, builds: 100),
        BitrisePlan(name: "Pro", cost: 210, builds: 250),
    ]
    
    /// リポジトリ名から iOS 用と判定（サフィックス -ios / _ios または "ios" が単語として含まれる場合。誤検出を避け "vision" 等は含めない）
    static func isIOSRepo(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasSuffix("-ios") || lower.hasSuffix("_ios") { return true }
        if lower.hasPrefix("ios") && (lower.count == 3 || lower.dropFirst(3).first == "-" || lower.dropFirst(3).first == "_") { return true }
        if lower.contains("-ios") || lower.contains("_ios") { return true }
        return false
    }
    
    /// リポジトリ名から Android 用と判定（サフィックス -android / _android または "android" が単語として含まれる場合）
    static func isAndroidRepo(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasSuffix("-android") || lower.hasSuffix("_android") { return true }
        if lower.hasPrefix("android") && (lower.count == 7 || lower.dropFirst(7).first == "-" || lower.dropFirst(7).first == "_") { return true }
        if lower.contains("-android") || lower.contains("_android") { return true }
        return false
    }
    
    /// 区切り - / _ と ios / android サフィックスを除いた部分をプロジェクト名として返す。一致する場合は同一プロジェクトとして集約する。
    static func projectName(from repository: String) -> String {
        let lower = repository.lowercased()
        if lower.hasSuffix("-ios") { return String(repository.dropLast(4)) }
        if lower.hasSuffix("_ios") { return String(repository.dropLast(4)) }
        if lower.hasSuffix("-android") { return String(repository.dropLast(8)) }
        if lower.hasSuffix("_android") { return String(repository.dropLast(8)) }
        return repository
    }
    
    static func getXcodePlan(hours: Double) -> XcodePlan {
        if hours <= 0 { return xcodePlans[0] }
        for plan in xcodePlans {
            if hours <= plan.hours { return plan }
        }
        return xcodePlans[xcodePlans.count - 1]
    }
    
    static func getBitrisePlan(totalBuilds: Int, hasIOS: Bool, hasAndroid: Bool) -> BitrisePlan {
        if totalBuilds > 100 { return bitrisePlans[4] }
        if hasIOS && hasAndroid { return bitrisePlans[2] }
        return bitrisePlans[1]
    }
    
    static func calculateGitHubActionsCost(iosMinutes: Double, androidMinutes: Double, useArm64: Bool = false) -> Double {
        let iosCost = iosMinutes * githubRates.macos
        let androidCost = androidMinutes * (useArm64 ? githubRates.linux8coreArm64 : githubRates.linux2core)
        return iosCost + androidCost
    }
    
    struct CaseCosts {
        let case1XcodeBitrise: Double
        let case2XcodeGitHub: Double
        let case3Bitrise: Double
        let case4GitHub: Double
        let case1XcodePlanName: String
        let case1BitrisePlanName: String
        let case3BitrisePlanName: String
    }
    
    static func calculateCaseCosts(
        iosHours: Double, androidHours: Double,
        iosBuilds: Int, androidBuilds: Int,
        otherHours: Double, otherBuilds: Int,
        hasIOS: Bool, hasAndroid: Bool
    ) -> CaseCosts {
        let iosMin = iosHours * 60
        let androidMin = androidHours * 60
        let otherMin = otherHours * 60
        let totalBuilds = iosBuilds + androidBuilds + otherBuilds
        
        let xcodePlan = getXcodePlan(hours: iosHours)
        let bitriseAndroidPlan = getBitrisePlan(totalBuilds: androidBuilds + otherBuilds, hasIOS: false, hasAndroid: hasAndroid || otherBuilds > 0)
        let case1 = xcodePlan.cost + bitriseAndroidPlan.cost
        
        let case2 = xcodePlan.cost + calculateGitHubActionsCost(iosMinutes: 0, androidMinutes: androidMin + otherMin, useArm64: false)
        
        let bitriseFullPlan = getBitrisePlan(totalBuilds: totalBuilds, hasIOS: hasIOS, hasAndroid: hasAndroid)
        let case3 = bitriseFullPlan.cost
        
        let case4 = calculateGitHubActionsCost(iosMinutes: iosMin + otherMin, androidMinutes: androidMin, useArm64: false)
        
        return CaseCosts(
            case1XcodeBitrise: case1,
            case2XcodeGitHub: case2,
            case3Bitrise: case3,
            case4GitHub: case4,
            case1XcodePlanName: xcodePlan.name,
            case1BitrisePlanName: bitriseAndroidPlan.name,
            case3BitrisePlanName: bitriseFullPlan.name
        )
    }
}
