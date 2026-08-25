import Foundation

enum StorageScanner {
    private struct Definition: Sendable {
        let name: String
        let relativePath: String
        let kind: StorageCategory.CategoryKind
    }

    static func scan() -> DiskSnapshot {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let attributes = (try? fileManager.attributesOfFileSystem(forPath: home)) ?? [:]
        let total = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0

        let definitions: [AgentKind: [Definition]] = [
            .codex: [
                Definition(name: "Active session history", relativePath: "sessions", kind: .sessions),
                Definition(name: "Archived session history", relativePath: "archived_sessions", kind: .sessions),
                Definition(name: "Visualizations", relativePath: "visualizations", kind: .other),
                Definition(name: "Skills and plugins", relativePath: "plugins", kind: .plugins),
                Definition(name: "Caches", relativePath: "cache", kind: .cache),
                Definition(name: "Logs", relativePath: "log", kind: .logs)
            ],
            .claude: [
                Definition(name: "Session history", relativePath: "projects", kind: .sessions),
                Definition(name: "File history", relativePath: "file-history", kind: .sessions),
                Definition(name: "Skills and plugins", relativePath: "plugins", kind: .plugins),
                Definition(name: "Caches", relativePath: "cache", kind: .cache),
                Definition(name: "Downloads", relativePath: "downloads", kind: .cache),
                Definition(name: "Debug logs", relativePath: "debug", kind: .logs)
            ],
            .grok: [
                Definition(name: "Session history", relativePath: "sessions", kind: .sessions),
                Definition(name: "Downloads", relativePath: "downloads", kind: .cache),
                Definition(name: "Marketplace cache", relativePath: "marketplace-cache", kind: .cache),
                Definition(name: "Installed plugins", relativePath: "installed-plugins", kind: .plugins),
                Definition(name: "Memory traces", relativePath: "memtrace", kind: .logs),
                Definition(name: "Logs", relativePath: "logs", kind: .logs)
            ]
        ]

        let rootNames: [AgentKind: String] = [.codex: ".codex", .claude: ".claude", .grok: ".grok"]
        let agents = AgentKind.allCases.map { agent -> AgentStorage in
            let root = "\(home)/\(rootNames[agent] ?? "")"
            let installed = fileManager.fileExists(atPath: root)
            let breakdown = installed ? Shell.directoryBreakdown(at: root) : [:]
            let categories = (definitions[agent] ?? []).compactMap { definition -> StorageCategory? in
                let path = "\(root)/\(definition.relativePath)"
                guard fileManager.fileExists(atPath: path) else { return nil }
                return StorageCategory(
                    id: "\(agent.rawValue):\(definition.relativePath)",
                    agent: agent,
                    name: definition.name,
                    path: path,
                    bytes: breakdown[path] ?? 0,
                    kind: definition.kind
                )
            }
            return AgentStorage(
                agent: agent,
                rootPath: root,
                totalBytes: breakdown[root] ?? 0,
                categories: categories.sorted { $0.bytes > $1.bytes },
                isInstalled: installed
            )
        }

        let sharedPath = "\(home)/dev/.worktrees"
        let shared: [StorageCategory]
        if fileManager.fileExists(atPath: sharedPath) {
            shared = [
                StorageCategory(
                    id: "shared:worktrees",
                    agent: nil,
                    name: "Git worktrees (last deep audit)",
                    path: sharedPath,
                    bytes: cachedWorktreeBytes(home: home),
                    kind: .worktrees
                )
            ]
        } else {
            shared = []
        }

        return DiskSnapshot(
            totalBytes: total,
            freeBytes: free,
            agents: agents,
            sharedCategories: shared,
            capturedAt: Date()
        )
    }

    private static func cachedWorktreeBytes(home: String) -> Int64 {
        let report = "\(home)/.codex-disk-space-management/reports/latest.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: report)),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audit = root["audit"] as? [String: Any],
              let codex = audit["codex"] as? [String: Any],
              let categories = codex["categories"] as? [[String: Any]] else { return 0 }

        return categories
            .filter { (($0["label"] as? String) ?? "").localizedCaseInsensitiveContains("Git worktrees") }
            .reduce(0) { total, category in
                total + ((category["bytes"] as? NSNumber)?.int64Value ?? 0)
            }
    }
}
