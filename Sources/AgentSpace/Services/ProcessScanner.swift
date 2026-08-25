import Foundation

enum ProcessScanner {
    private struct Aggregate {
        var residentBytes: Int64 = 0
        var processCount = 0
    }

    static func scan() -> RuntimeSnapshot {
        let result = Shell.run("/bin/ps", ["-axo", "rss=,command="], timeout: 3)
        guard result.status == 0 else { return .empty }

        var aggregates: [AgentKind: Aggregate] = [:]
        for line in result.stdout.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }),
                  let residentKilobytes = Int64(trimmed[..<separator]) else { continue }
            let command = String(trimmed[separator...]).trimmingCharacters(in: .whitespaces)
            guard let agent = agent(for: command) else { continue }
            aggregates[agent, default: Aggregate()].residentBytes += residentKilobytes * 1_024
            aggregates[agent, default: Aggregate()].processCount += 1
        }

        return RuntimeSnapshot(
            agents: AgentKind.allCases.map { agent in
                let aggregate = aggregates[agent] ?? Aggregate()
                return AgentRuntime(
                    agent: agent,
                    residentBytes: aggregate.residentBytes,
                    processCount: aggregate.processCount
                )
            },
            capturedAt: Date()
        )
    }

    static func agent(for command: String) -> AgentKind? {
        let lowercased = command.lowercased()
        if lowercased.contains("/agent space.app/") || lowercased.contains("/agentspace") { return nil }
        if lowercased.contains("/codex limits.app/") || lowercased.contains("/codex-router/") { return nil }
        if lowercased.contains("/cursor.app/") { return .cursor }
        if lowercased.contains("/opencode.app/") || executable(lowercased, isNamed: "opencode") { return .openCode }
        if lowercased.contains("/.hermes/hermes-agent/run_agent.py")
            || lowercased.contains("/.hermes/hermes-agent/hermes_cli")
            || executable(lowercased, isNamed: "hermes") { return .hermes }
        if lowercased.contains("/.local/bin/ori") || executable(lowercased, isNamed: "ori") { return .ori }
        if lowercased.contains("/.grok/bin/grok") || executable(lowercased, isNamed: "grok") { return .grok }
        if lowercased.contains("/claude.app/") || lowercased.contains("/.local/bin/claude") || executable(lowercased, isNamed: "claude") { return .claude }
        if lowercased.contains("/codex.app/")
            || lowercased.contains("/chatgpt.app/contents/frameworks/codex framework.framework/")
            || lowercased.contains("/chatgpt.app/contents/resources/codex ")
            || executable(lowercased, isNamed: "codex") { return .codex }
        return nil
    }

    private static func executable(_ command: String, isNamed name: String) -> Bool {
        guard let executablePath = command.split(separator: " ").first else { return false }
        return executablePath == name || executablePath.hasSuffix("/\(name)")
    }
}
