import Foundation

enum RegenerableCleanupError: LocalizedError, Equatable {
    case nothingEligible
    case invalidTarget(String)
    case symbolicLink(String)
    case noLongerSafe(String)

    var errorDescription: String? {
        switch self {
        case .nothingEligible:
            "There is nothing eligible to move to the Trash."
        case let .invalidTarget(path):
            "CleanMyAgent refused \(path) because it is outside the allowlist."
        case let .symbolicLink(path):
            "CleanMyAgent refused \(path) because it is a symbolic link."
        case let .noLongerSafe(reason):
            "A target changed after the audit and is now protected: \(reason)"
        }
    }
}

enum RegenerableCleanupService {
    typealias TrashOperation = @Sendable (URL) throws -> URL?
    typealias CodexRunningCheck = @Sendable () -> Bool

    private struct CacheDefinition {
        let id: String
        let title: String
        let relativePath: String
        let requiresCodexClosed: Bool
    }

    private static let cacheDefinitions: [CacheDefinition] = [
        CacheDefinition(id: "npm-cacache", title: "npm package cache", relativePath: ".npm/_cacache", requiresCodexClosed: false),
        CacheDefinition(id: "yarn-cache", title: "Yarn cache", relativePath: "Library/Caches/Yarn", requiresCodexClosed: false),
        CacheDefinition(id: "playwright", title: "Playwright browsers", relativePath: "Library/Caches/ms-playwright", requiresCodexClosed: false),
        CacheDefinition(id: "puppeteer", title: "Puppeteer browsers", relativePath: ".cache/puppeteer", requiresCodexClosed: false),
        CacheDefinition(id: "codex-library-cache", title: "Codex library cache", relativePath: "Library/Caches/com.openai.codex", requiresCodexClosed: true),
        CacheDefinition(id: "codex-named-cache", title: "Codex cache", relativePath: "Library/Caches/Codex", requiresCodexClosed: true),
        CacheDefinition(id: "codex-runtimes", title: "Codex runtimes", relativePath: ".cache/codex-runtimes", requiresCodexClosed: true)
    ]

    static func scan(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        worktrees: [WorktreeRecord],
        isCodexRunning: Bool
    ) -> RegenerableCleanupSnapshot {
        let home = homeURL.standardizedFileURL
        var items: [RegenerableCleanupItem] = []
        var skippedActiveWorktrees = 0

        for record in worktrees {
            if record.isBare || record.isLocked { continue }
            if record.hasActiveProcesses {
                skippedActiveWorktrees += 1
                continue
            }
            for directory in nodeModuleDirectories(in: record.path) {
                items.append(makeDependencyItem(directory: directory, worktree: record))
            }
        }

        for definition in cacheDefinitions {
            let url = home.appendingPathComponent(definition.relativePath, isDirectory: true).standardizedFileURL
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            guard exists else { continue }

            var blocked: String?
            if isSymbolicLink(url) {
                blocked = "The cache folder is a symbolic link"
            } else if definition.requiresCodexClosed && isCodexRunning {
                blocked = "Quit Codex to clean this cache"
            }

            items.append(
                RegenerableCleanupItem(
                    id: definition.id,
                    family: .developerCaches,
                    title: definition.title,
                    path: url.path,
                    bytes: Shell.directoryBytes(at: url.path),
                    blockedReason: blocked
                )
            )
        }

        return RegenerableCleanupSnapshot(
            items: items,
            skippedActiveWorktrees: skippedActiveWorktrees,
            capturedAt: Date()
        )
    }

    static func moveToTrash(
        _ family: RegenerableCleanupFamily,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        worktrees: [WorktreeRecord],
        isCodexRunning: CodexRunningCheck = { false },
        trash: TrashOperation = systemTrash
    ) -> RegenerableCleanupResult {
        let running = isCodexRunning()
        let snapshot = scan(homeURL: homeURL, worktrees: worktrees, isCodexRunning: running)
        let eligible = snapshot.eligibleItems(in: family)
        guard !eligible.isEmpty else {
            return RegenerableCleanupResult(
                trashedPaths: [],
                reclaimedBytes: 0,
                failures: [RegenerableCleanupFailure(path: "", message: RegenerableCleanupError.nothingEligible.localizedDescription)]
            )
        }

        var trashedPaths: [String] = []
        var reclaimedBytes: Int64 = 0
        var failures: [RegenerableCleanupFailure] = []

        for item in eligible {
            do {
                try validate(item, family: family, homeURL: homeURL, worktrees: worktrees, isCodexRunning: running)
                let url = URL(fileURLWithPath: item.path, isDirectory: true)
                _ = try trash(url)
                trashedPaths.append(item.path)
                reclaimedBytes += item.bytes
            } catch {
                failures.append(RegenerableCleanupFailure(path: item.path, message: error.localizedDescription))
            }
        }

        return RegenerableCleanupResult(
            trashedPaths: trashedPaths.sorted(),
            reclaimedBytes: reclaimedBytes,
            failures: failures
        )
    }

    private static func validate(
        _ item: RegenerableCleanupItem,
        family: RegenerableCleanupFamily,
        homeURL: URL,
        worktrees: [WorktreeRecord],
        isCodexRunning: Bool
    ) throws {
        let url = URL(fileURLWithPath: item.path).standardizedFileURL
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values?.isSymbolicLink != true else {
            throw RegenerableCleanupError.symbolicLink(item.path)
        }
        guard values?.isDirectory == true else {
            throw RegenerableCleanupError.noLongerSafe("the folder is no longer a directory")
        }

        switch family {
        case .developerCaches:
            let allowed = cacheDefinitions.map {
                homeURL.appendingPathComponent($0.relativePath, isDirectory: true).standardizedFileURL.path
            }
            guard allowed.contains(url.path) else {
                throw RegenerableCleanupError.invalidTarget(item.path)
            }
            if let definition = cacheDefinitions.first(where: {
                homeURL.appendingPathComponent($0.relativePath, isDirectory: true).standardizedFileURL.path == url.path
            }), definition.requiresCodexClosed, isCodexRunning {
                throw RegenerableCleanupError.noLongerSafe("Codex is running")
            }
        case .worktreeDependencies:
            guard url.lastPathComponent == "node_modules" else {
                throw RegenerableCleanupError.invalidTarget(item.path)
            }
            guard let worktree = worktrees.first(where: {
                url.path == $0.path || url.path.hasPrefix($0.path + "/")
            }) else {
                throw RegenerableCleanupError.invalidTarget(item.path)
            }
            guard !worktree.hasActiveProcesses else {
                throw RegenerableCleanupError.noLongerSafe("a running process is using this worktree")
            }
            guard isGitIgnored(path: url.path, worktreePath: worktree.path) else {
                throw RegenerableCleanupError.noLongerSafe("node_modules is not gitignored")
            }
        }
    }

    private static func makeDependencyItem(directory: URL, worktree: WorktreeRecord) -> RegenerableCleanupItem {
        var blocked: String?
        if isSymbolicLink(directory) {
            blocked = "The folder is a symbolic link"
        } else if !isGitIgnored(path: directory.path, worktreePath: worktree.path) {
            blocked = "node_modules is not gitignored in this worktree"
        }

        let relative = directory.path.hasPrefix(worktree.path + "/")
            ? String(directory.path.dropFirst(worktree.path.count + 1))
            : directory.lastPathComponent

        return RegenerableCleanupItem(
            id: directory.path,
            family: .worktreeDependencies,
            title: "\(worktree.repository)/\(relative)",
            path: directory.path,
            bytes: Shell.directoryBytes(at: directory.path),
            blockedReason: blocked
        )
    }

    private static func nodeModuleDirectories(in worktreePath: String) -> [URL] {
        let root = URL(fileURLWithPath: worktreePath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        var directories: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            guard item.lastPathComponent == "node_modules" else { continue }
            enumerator.skipDescendants()
            directories.append(item.standardizedFileURL)
        }
        return directories
    }

    private static func isGitIgnored(path: String, worktreePath: String) -> Bool {
        let relative: String
        if path == worktreePath {
            relative = "."
        } else if path.hasPrefix(worktreePath + "/") {
            relative = String(path.dropFirst(worktreePath.count + 1))
        } else {
            return false
        }
        return Shell.run(
            "/usr/bin/git",
            ["-C", worktreePath, "check-ignore", "-q", "--", relative],
            timeout: 3
        ).status == 0
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func systemTrash(_ url: URL) throws -> URL? {
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }
}
