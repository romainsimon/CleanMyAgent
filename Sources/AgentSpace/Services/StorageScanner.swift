import Foundation

enum StorageScanner {
    private struct CategoryDefinition {
        let name: String
        let paths: [String]
        let exclusions: [String]
        let kind: StorageCategory.CategoryKind

        init(
            name: String,
            paths: [String],
            exclusions: [String] = [],
            kind: StorageCategory.CategoryKind
        ) {
            self.name = name
            self.paths = paths
            self.exclusions = exclusions
            self.kind = kind
        }
    }

    private struct AdapterDefinition {
        let primaryPath: String
        let roots: [String]
        let exclusions: [String]
        let installationPaths: [String]
        let categories: [CategoryDefinition]
        let version: String?
    }

    static func scan() -> DiskSnapshot {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let attributes = (try? fileManager.attributesOfFileSystem(forPath: home)) ?? [:]
        let total = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let definitions = adapterDefinitions(home: home)
        var byteCache: [String: Int64] = [:]

        func bytes(at path: String) -> Int64 {
            if let cached = byteCache[path] { return cached }
            let measured = Shell.directoryBytes(at: path)
            byteCache[path] = measured
            return measured
        }

        for definition in definitions.values {
            for root in definition.roots where fileManager.fileExists(atPath: root) {
                let breakdown = Shell.directoryBreakdown(at: root)
                byteCache.merge(breakdown) { _, new in new }
                if byteCache[root] == nil { byteCache[root] = Shell.directoryBytes(at: root) }
            }
        }

        let agents = AgentKind.allCases.map { agent -> AgentStorage in
            guard let definition = definitions[agent] else {
                return AgentStorage(
                    agent: agent,
                    rootPath: "",
                    totalBytes: 0,
                    categories: [],
                    isInstalled: false,
                    version: nil
                )
            }
            let installed = definition.installationPaths.contains { fileManager.fileExists(atPath: $0) }
            let rootBytes = definition.roots.reduce(Int64(0)) { $0 + bytes(at: $1) }
            let excludedBytes = definition.exclusions.reduce(Int64(0)) { $0 + bytes(at: $1) }
            let totalBytes = max(0, rootBytes - excludedBytes)
            let categories = definition.categories.compactMap { category -> StorageCategory? in
                let existingPaths = category.paths.filter { fileManager.fileExists(atPath: $0) }
                guard !existingPaths.isEmpty else { return nil }
                let measured = existingPaths.reduce(Int64(0)) { $0 + bytes(at: $1) }
                let excluded = category.exclusions.reduce(Int64(0)) { $0 + bytes(at: $1) }
                return StorageCategory(
                    id: "\(agent.rawValue):\(category.name)",
                    agent: agent,
                    name: category.name,
                    path: existingPaths[0],
                    bytes: max(0, measured - excluded),
                    kind: category.kind
                )
            }
            return AgentStorage(
                agent: agent,
                rootPath: definition.primaryPath,
                totalBytes: totalBytes,
                categories: categories.sorted { $0.bytes > $1.bytes },
                isInstalled: installed,
                version: definition.version
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

    private static func adapterDefinitions(home: String) -> [AgentKind: AdapterDefinition] {
        let cursorData = "\(home)/Library/Application Support/Cursor"
        let cursorHome = "\(home)/.cursor"
        let kiloExtensions = childDirectories(in: "\(cursorHome)/extensions", prefix: "kilocode.kilo-code-")
        let kiloWorkspace = "\(cursorData)/User/globalStorage/kilocode.kilo-code"
        let kiloPaths = kiloExtensions + [kiloWorkspace]
        let newestKilo = kiloExtensions.sorted().last
        let openCodeData = "\(home)/.local/share/opencode"
        let openCodeConfig = "\(home)/.config/opencode"
        let openCodeApp = "/Applications/OpenCode.app"

        return [
            .codex: singleRoot(
                home: home,
                rootName: ".codex",
                version: commandVersion("/opt/homebrew/bin/codex", arguments: ["--version"]),
                categories: [
                    ("Active session history", "sessions", .sessions),
                    ("Archived session history", "archived_sessions", .sessions),
                    ("Visualizations", "visualizations", .other),
                    ("Skills and plugins", "plugins", .plugins),
                    ("Caches", "cache", .cache),
                    ("Logs", "log", .logs)
                ]
            ),
            .claude: singleRoot(
                home: home,
                rootName: ".claude",
                version: commandVersion("\(home)/.local/bin/claude", arguments: ["--version"]),
                categories: [
                    ("Session history", "projects", .sessions),
                    ("File history", "file-history", .sessions),
                    ("Skills and plugins", "plugins", .plugins),
                    ("Caches", "cache", .cache),
                    ("Downloads", "downloads", .cache),
                    ("Debug logs", "debug", .logs)
                ]
            ),
            .grok: singleRoot(
                home: home,
                rootName: ".grok",
                version: jsonString(at: "\(home)/.grok/version.json", key: "version"),
                categories: [
                    ("Session history", "sessions", .sessions),
                    ("Downloads", "downloads", .cache),
                    ("Marketplace cache", "marketplace-cache", .cache),
                    ("Installed plugins", "installed-plugins", .plugins),
                    ("Memory traces", "memtrace", .logs),
                    ("Logs", "logs", .logs)
                ]
            ),
            .cursor: AdapterDefinition(
                primaryPath: cursorHome,
                roots: [cursorHome, cursorData],
                exclusions: kiloPaths,
                installationPaths: ["/Applications/Cursor.app", cursorHome, cursorData],
                categories: [
                    CategoryDefinition(name: "Git worktrees", paths: ["\(cursorHome)/worktrees"], kind: .worktrees),
                    CategoryDefinition(name: "Snapshots", paths: ["\(cursorHome)/snapshots"], kind: .sessions),
                    CategoryDefinition(
                        name: "Extensions",
                        paths: ["\(cursorHome)/extensions"],
                        exclusions: kiloExtensions,
                        kind: .plugins
                    ),
                    CategoryDefinition(
                        name: "Workspace and chat data",
                        paths: ["\(cursorData)/User"],
                        exclusions: [kiloWorkspace],
                        kind: .sessions
                    ),
                    CategoryDefinition(
                        name: "Caches and downloads",
                        paths: [
                            "\(cursorData)/CachedData",
                            "\(cursorData)/CachedExtensionVSIXs",
                            "\(cursorData)/Cache",
                            "\(cursorData)/Code Cache",
                            "\(cursorData)/GPUCache",
                            "\(cursorData)/DawnWebGPUCache"
                        ],
                        kind: .cache
                    ),
                    CategoryDefinition(
                        name: "Logs and process data",
                        paths: ["\(cursorData)/logs", "\(cursorData)/process-monitor"],
                        kind: .logs
                    ),
                    CategoryDefinition(
                        name: "Projects, skills, and plugins",
                        paths: [
                            "\(cursorHome)/projects",
                            "\(cursorHome)/plugins",
                            "\(cursorHome)/skills",
                            "\(cursorHome)/ai-tracking"
                        ],
                        kind: .plugins
                    )
                ],
                version: appVersion(at: "/Applications/Cursor.app")
            ),
            .hermes: AdapterDefinition(
                primaryPath: "\(home)/.hermes",
                roots: ["\(home)/.hermes"],
                exclusions: [],
                installationPaths: ["\(home)/.local/bin/hermes", "\(home)/.hermes"],
                categories: [
                    CategoryDefinition(
                        name: "Runtime and dependencies",
                        paths: ["\(home)/.hermes/hermes-agent", "\(home)/.hermes/node", "\(home)/.hermes/lsp"],
                        kind: .other
                    ),
                    CategoryDefinition(
                        name: "Sessions and state",
                        paths: ["\(home)/.hermes/sessions", "\(home)/.hermes/state.db", "\(home)/.hermes/state.db-wal"],
                        kind: .sessions
                    ),
                    CategoryDefinition(name: "Skills", paths: ["\(home)/.hermes/skills"], kind: .plugins),
                    CategoryDefinition(name: "Logs", paths: ["\(home)/.hermes/logs"], kind: .logs),
                    CategoryDefinition(
                        name: "Caches",
                        paths: ["\(home)/.hermes/cache", "\(home)/.hermes/bootstrap-cache", "\(home)/.hermes/checkpoints"],
                        kind: .cache
                    )
                ],
                version: tomlVersion(at: "\(home)/.hermes/hermes-agent/pyproject.toml")
            ),
            .openCode: AdapterDefinition(
                primaryPath: openCodeData,
                roots: [openCodeData, openCodeConfig, openCodeApp],
                exclusions: [],
                installationPaths: [openCodeApp, openCodeData, "\(home)/.local/bin/opencode"],
                categories: [
                    CategoryDefinition(name: "Desktop application", paths: [openCodeApp], kind: .other),
                    CategoryDefinition(
                        name: "Session database",
                        paths: ["\(openCodeData)/opencode.db", "\(openCodeData)/opencode.db-wal", "\(openCodeData)/opencode.db-shm"],
                        kind: .sessions
                    ),
                    CategoryDefinition(name: "Snapshots", paths: ["\(openCodeData)/snapshot"], kind: .sessions),
                    CategoryDefinition(name: "Logs", paths: ["\(openCodeData)/log"], kind: .logs),
                    CategoryDefinition(name: "Configuration and plugins", paths: [openCodeConfig], kind: .plugins),
                    CategoryDefinition(
                        name: "Tool output and repositories",
                        paths: ["\(openCodeData)/tool-output", "\(openCodeData)/repos"],
                        kind: .other
                    )
                ],
                version: appVersion(at: openCodeApp)
            ),
            .ori: AdapterDefinition(
                primaryPath: "\(home)/.ori",
                roots: ["\(home)/.ori", "\(home)/.local/bin/ori"],
                exclusions: [],
                installationPaths: ["\(home)/.local/bin/ori", "\(home)/.ori"],
                categories: [
                    CategoryDefinition(name: "CLI runtime", paths: ["\(home)/.local/bin/ori"], kind: .other),
                    CategoryDefinition(name: "Global workspace", paths: ["\(home)/.ori/global"], kind: .plugins),
                    CategoryDefinition(
                        name: "Launcher history",
                        paths: [
                            "\(home)/.ori/logs",
                            "\(home)/.ori/prompt-history.sqlite",
                            "\(home)/.ori/prompt-history.sqlite-wal",
                            "\(home)/.ori/prompt-history.sqlite-shm"
                        ],
                        kind: .sessions
                    ),
                    CategoryDefinition(name: "Daemon state", paths: ["\(home)/.ori/daemon"], kind: .logs)
                ],
                version: oriVersion(home: home)
            ),
            .kiloCode: AdapterDefinition(
                primaryPath: newestKilo ?? kiloWorkspace,
                roots: kiloPaths,
                exclusions: [],
                installationPaths: kiloPaths,
                categories: [
                    CategoryDefinition(name: "Cursor extension", paths: kiloExtensions, kind: .plugins),
                    CategoryDefinition(name: "Workspace data", paths: [kiloWorkspace], kind: .sessions)
                ],
                version: newestKilo.flatMap { jsonString(at: "\($0)/package.json", key: "version") }
            )
        ]
    }

    private static func singleRoot(
        home: String,
        rootName: String,
        version: String?,
        categories: [(String, String, StorageCategory.CategoryKind)]
    ) -> AdapterDefinition {
        let root = "\(home)/\(rootName)"
        return AdapterDefinition(
            primaryPath: root,
            roots: [root],
            exclusions: [],
            installationPaths: [root],
            categories: categories.map {
                CategoryDefinition(name: $0.0, paths: ["\(root)/\($0.1)"], kind: $0.2)
            },
            version: version
        )
    }

    private static func childDirectories(in path: String, prefix: String) -> [String] {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
        return children
            .filter { $0.hasPrefix(prefix) }
            .map { "\(path)/\($0)" }
            .filter { fileManager.fileExists(atPath: $0) }
    }

    private static func appVersion(at path: String) -> String? {
        let plistPath = "\(path)/Contents/Info.plist"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return dictionary["CFBundleShortVersionString"] as? String
    }

    private static func jsonString(at path: String, key: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return dictionary[key] as? String
    }

    private static func tomlVersion(at path: String) -> String? {
        guard let source = try? String(contentsOfFile: path, encoding: .utf8),
              let match = source.firstMatch(of: /(?m)^version\s*=\s*"([^"]+)"/) else { return nil }
        return String(match.1)
    }

    private static func oriVersion(home: String) -> String? {
        let executable = "\(home)/.local/bin/ori"
        guard FileManager.default.fileExists(atPath: executable) else { return nil }
        let result = Shell.run(executable, ["version", "--json"], timeout: 2)
        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any] else {
            return jsonString(at: "\(home)/.ori/update-check.json", key: "latestVersion")
        }
        return payload["version"] as? String
    }

    private static func commandVersion(_ executable: String, arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let result = Shell.run(executable, arguments, timeout: 2)
        guard result.status == 0 else { return nil }
        return result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first(where: { $0.first?.isNumber == true })
            .map(String.init)
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
