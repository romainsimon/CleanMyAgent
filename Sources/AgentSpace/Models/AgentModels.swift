import Foundation

enum AgentKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case codex = "Codex"
    case claude = "Claude Code"
    case grok = "Grok"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .codex: "terminal"
        case .claude: "sparkles"
        case .grok: "bolt.horizontal"
        }
    }

    var iconResourceName: String {
        switch self {
        case .codex: "codex"
        case .claude: "claude"
        case .grok: "grok"
        }
    }

    var accentName: String {
        switch self {
        case .codex: "codex"
        case .claude: "claude"
        case .grok: "grok"
        }
    }
}

struct StorageCategory: Identifiable, Sendable, Hashable {
    let id: String
    let agent: AgentKind?
    let name: String
    let path: String
    let bytes: Int64
    let kind: CategoryKind

    enum CategoryKind: String, Sendable {
        case sessions
        case cache
        case plugins
        case logs
        case worktrees
        case other
    }
}

struct AgentStorage: Identifiable, Sendable {
    let agent: AgentKind
    let rootPath: String
    let totalBytes: Int64
    let categories: [StorageCategory]
    let isInstalled: Bool

    var id: AgentKind { agent }
}

struct DiskSnapshot: Sendable {
    let totalBytes: Int64
    let freeBytes: Int64
    let agents: [AgentStorage]
    let sharedCategories: [StorageCategory]
    let capturedAt: Date

    static let empty = DiskSnapshot(
        totalBytes: 0,
        freeBytes: 0,
        agents: AgentKind.allCases.map {
            AgentStorage(agent: $0, rootPath: "", totalBytes: 0, categories: [], isInstalled: false)
        },
        sharedCategories: [],
        capturedAt: .distantPast
    )

    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var freeFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }

    var pressure: DiskPressure {
        guard totalBytes > 0 else { return .unknown }
        if freeBytes < 5 * 1_073_741_824 { return .critical }
        if freeBytes < 20 * 1_073_741_824 { return .warning }
        return .healthy
    }
}

enum DiskPressure: String, Sendable {
    case unknown = "Scanning"
    case healthy = "Healthy"
    case warning = "Low space"
    case critical = "Critical"
}

struct CleanupTargetSnapshot: Sendable, Equatable {
    let path: String
    let bytes: Int64
    let fileCount: Int
    let exists: Bool
    let capturedAt: Date

    static let empty = CleanupTargetSnapshot(
        path: "~/.codex/archived_sessions",
        bytes: 0,
        fileCount: 0,
        exists: false,
        capturedAt: .distantPast
    )
}

enum CleanupOperationState: Sendable, Equatable {
    case idle
    case movingToTrash
    case succeeded(trashedPath: String)
    case failed(message: String)
}

struct AgentMetric: Identifiable, Sendable {
    let agent: AgentKind
    let model: String
    let observedTokensPerSecond: Double?
    let timeToFirstTokenMs: Double?
    let responseDurationMs: Double?
    let inputTokens: Int64
    let outputTokens: Int64
    let cachedTokens: Int64
    let reasoningTokens: Int64
    let sampleCount: Int
    let coverage: String
    let capturedAt: Date?

    var id: AgentKind { agent }

    static func unavailable(_ agent: AgentKind, coverage: String) -> AgentMetric {
        AgentMetric(
            agent: agent,
            model: "Unavailable",
            observedTokensPerSecond: nil,
            timeToFirstTokenMs: nil,
            responseDurationMs: nil,
            inputTokens: 0,
            outputTokens: 0,
            cachedTokens: 0,
            reasoningTokens: 0,
            sampleCount: 0,
            coverage: coverage,
            capturedAt: nil
        )
    }
}

struct PerformanceSnapshot: Sendable {
    let metrics: [AgentMetric]
    let capturedAt: Date

    static let empty = PerformanceSnapshot(
        metrics: AgentKind.allCases.map { .unavailable($0, coverage: "Waiting for first scan") },
        capturedAt: .distantPast
    )
}

struct LiveSpeedSnapshot: Sendable {
    let active: Bool
    let agent: AgentKind
    let model: String?
    let observedTokensPerSecond: Double
    let outputTokens: Int64
    let totalTokens: Int64
    let elapsedMs: Double
    let sampledAt: Date

    static let inactive = LiveSpeedSnapshot(
        active: false,
        agent: .codex,
        model: nil,
        observedTokensPerSecond: 0,
        outputTokens: 0,
        totalTokens: 0,
        elapsedMs: 0,
        sampledAt: .distantPast
    )
}

enum UsageRange: Int, CaseIterable, Identifiable, Sendable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90

    var id: Int { rawValue }
    var label: String { "\(rawValue)d" }
    var title: String { "Last \(rawValue) days" }
}

struct UsageBucket: Identifiable, Sendable, Hashable {
    let date: Date
    let agent: AgentKind
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheWriteTokens: Int64
    let reasoningTokens: Int64
    let sessions: Int

    var id: String { "\(date.timeIntervalSince1970)-\(agent.rawValue)" }
    var totalTokens: Int64 { inputTokens + outputTokens }
    var uncachedInputTokens: Int64 { max(0, inputTokens - cacheReadTokens - cacheWriteTokens) }
    var visibleOutputTokens: Int64 { max(0, outputTokens - reasoningTokens) }
}

struct ModelUsage: Identifiable, Sendable, Hashable {
    let agent: AgentKind
    let model: String
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheWriteTokens: Int64
    let reasoningTokens: Int64
    let sessions: Int

    var id: String { "\(agent.rawValue)-\(model)" }
    var totalTokens: Int64 { inputTokens + outputTokens }
}

struct UsageCoverage: Identifiable, Sendable, Hashable {
    let agent: AgentKind
    let filesDiscovered: Int
    let filesScanned: Int
    let truncatedFiles: Int
    let note: String

    var id: AgentKind { agent }
}

struct UsageSnapshot: Sendable {
    let range: UsageRange
    let buckets: [UsageBucket]
    let models: [ModelUsage]
    let coverage: [UsageCoverage]
    let sessionCount: Int
    let capturedAt: Date

    static func empty(range: UsageRange = .thirtyDays) -> UsageSnapshot {
        UsageSnapshot(range: range, buckets: [], models: [], coverage: [], sessionCount: 0, capturedAt: .distantPast)
    }

    var inputTokens: Int64 { buckets.reduce(0) { $0 + $1.inputTokens } }
    var outputTokens: Int64 { buckets.reduce(0) { $0 + $1.outputTokens } }
    var cacheReadTokens: Int64 { buckets.reduce(0) { $0 + $1.cacheReadTokens } }
    var cacheWriteTokens: Int64 { buckets.reduce(0) { $0 + $1.cacheWriteTokens } }
    var reasoningTokens: Int64 { buckets.reduce(0) { $0 + $1.reasoningTokens } }
    var totalTokens: Int64 { inputTokens + outputTokens }
    var hasPartialCoverage: Bool {
        coverage.contains { $0.truncatedFiles > 0 || $0.filesScanned < $0.filesDiscovered }
    }
}

struct WorktreeRecord: Identifiable, Sendable, Hashable {
    let path: String
    let repository: String
    let branch: String
    let head: String
    let bytes: Int64
    let isDirty: Bool
    let statusKnown: Bool
    let isBare: Bool
    let isLocked: Bool

    var id: String { path }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case agents = "Agents"
    case performance = "Performance"
    case usage = "Usage"
    case storage = "Storage"
    case worktrees = "Worktrees"
    case cleanup = "Clean"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .agents: "cpu"
        case .performance: "speedometer"
        case .usage: "chart.xyaxis.line"
        case .storage: "internaldrive"
        case .worktrees: "arrow.triangle.branch"
        case .cleanup: "trash.slash"
        case .settings: "gearshape"
        }
    }
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}
