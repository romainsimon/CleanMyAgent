import Foundation

// Deterministic, public sample data for screenshots. No live scan or cleanup runs in --demo mode.
enum DemoData {
    private static let gb: Int64 = 1_073_741_824
    static let disk = DiskSnapshot(totalBytes: 512 * gb, freeBytes: 83 * gb, agents: AgentKind.allCases.enumerated().map { index, agent in
        let bytes = Int64([18, 12, 3, 8, 2, 4, 1, 2][index]) * gb
        return AgentStorage(agent: agent, rootPath: "~/Library/Agent data/\(agent.rawValue)", totalBytes: bytes, categories: [StorageCategory(id: agent.rawValue, agent: agent, name: "Sessions and local data", path: "~/Library/Agent data/\(agent.rawValue)", bytes: bytes, kind: .sessions)], isInstalled: true, version: nil)
    }, sharedCategories: [StorageCategory(id: "shared:worktrees", agent: nil, name: "Git worktrees", path: "~/dev/.worktrees", bytes: 26 * gb, kind: .worktrees)], capturedAt: Date())
    static let runtime = RuntimeSnapshot(agents: AgentKind.allCases.map { AgentRuntime(agent: $0, residentBytes: $0 == .codex ? 412 * 1_048_576 : 0, processCount: $0 == .codex ? 3 : 0) }, capturedAt: Date())
    static let performance = PerformanceSnapshot(metrics: AgentKind.allCases.map { agent in
        AgentMetric(agent: agent, model: agent == .codex ? "Codex model" : "Local agent", observedTokensPerSecond: agent == .codex ? 54.2 : nil, timeToFirstTokenMs: agent == .codex ? 820 : nil, responseDurationMs: agent == .codex ? 12_400 : nil, inputTokens: 12_400, outputTokens: 860, cachedTokens: 8_200, reasoningTokens: 120, sampleCount: agent == .codex ? 28 : 0, coverage: "Demo data. Actual metric coverage varies by agent.", capturedAt: Date())
    }, capturedAt: Date())
    static let worktrees: [WorktreeRecord] = [
        record("shop", "codex/checkout-flow", gb * 8, .removable, "HEAD is already contained in the default branch"),
        record("website", "claude/pricing-copy", gb * 3, .removable, "This exact HEAD belongs to a merged pull request"),
        record("notes", "codex/search", gb * 4, .protected, "Contains uncommitted changes"),
        record("api", "claude/auth", gb * 2, .protected, "Contains ignored files or folders without a verified copy in the primary checkout"),
        record("studio", "codex/editor", gb * 9, .protected, "A running process is using this worktree")
    ]
    private static func record(_ repository: String, _ branch: String, _ bytes: Int64, _ safety: WorktreeSafety, _ reason: String) -> WorktreeRecord {
        WorktreeRecord(path: "~/dev/.worktrees/\(repository)/\(branch.replacingOccurrences(of: "/", with: "-"))", repositoryPath: "~/dev/\(repository)", repository: repository, branch: branch, head: "a1b2c3d4", bytes: bytes, isDirty: repository == "notes", hasUntrackedFiles: false, hasUnpushedCommits: false, hasActiveProcesses: repository == "studio", statusKnown: true, isBare: false, isLocked: false, pullRequest: WorktreePullRequest(state: safety == .removable ? .merged : .open, url: nil, headOID: "a1b2c3d4"), safety: safety, safetyReason: reason)
    }
    static let cleanup = RegenerableCleanupSnapshot(items: [
        RegenerableCleanupItem(id: "demo-deps", family: .worktreeDependencies, title: "shop/node_modules", path: "~/dev/.worktrees/shop/node_modules", bytes: gb * 5, blockedReason: nil),
        RegenerableCleanupItem(id: "npm-cacache", family: .developerCaches, title: "npm package cache", path: "~/.npm/_cacache", bytes: gb * 3, blockedReason: nil),
        RegenerableCleanupItem(id: "playwright", family: .developerCaches, title: "Playwright browsers", path: "~/Library/Caches/ms-playwright", bytes: gb * 2, blockedReason: nil)
    ], skippedActiveWorktrees: 1, capturedAt: Date())
    static func usage(range: UsageRange) -> UsageSnapshot {
        var buckets: [UsageBucket] = []
        for day in 0..<range.rawValue {
            let date = Calendar.current.startOfDay(for: Date().addingTimeInterval(Double(-day) * 86_400))
            let agent: AgentKind = day % 2 == 0 ? .codex : .claude
            let input = Int64(40_000 + (day * 7919) % 60_000)
            let output = Int64(9_000 + (day * 3571) % 18_000)
            buckets.append(UsageBucket(date: date, agent: agent, inputTokens: input, outputTokens: output, cacheReadTokens: 24_000, cacheWriteTokens: 4_000, reasoningTokens: 2_000, reportedCostUSD: 0, sessions: 4))
        }
        return UsageSnapshot(range: range, buckets: buckets, models: [ModelUsage(agent: .codex, model: "Codex model", inputTokens: 1_280_000, outputTokens: 410_000, cacheReadTokens: 780_000, cacheWriteTokens: 110_000, reasoningTokens: 46_000, reportedCostUSD: 0, sessions: 64)], coverage: AgentKind.allCases.map { UsageCoverage(agent: $0, filesDiscovered: 28, filesScanned: 28, truncatedFiles: 0, status: .measured, note: "Demo data. Provider cost is only shown when present in local records.") }, sessionCount: range.rawValue * 4, capturedAt: Date())
    }
}
