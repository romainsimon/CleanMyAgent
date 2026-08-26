import Foundation
import Testing
@testable import AgentSpace

struct RegenerableCleanupServiceTests {
    @Test func trashesAllowlistedCachesAndLeavesSessionsAlone() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = root.appendingPathComponent(".npm/_cacache", isDirectory: true)
        let sessions = root.appendingPathComponent(".codex/sessions", isDirectory: true)
        let trash = root.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try Data("pkg".utf8).write(to: cache.appendingPathComponent("index.json"))
        try Data("secret-session".utf8).write(to: sessions.appendingPathComponent("rollout.jsonl"))

        let snapshot = RegenerableCleanupService.scan(homeURL: root, worktrees: [], isCodexRunning: false)
        #expect(snapshot.eligibleItems(in: .developerCaches).contains { $0.path == cache.path })
        #expect(!snapshot.items.contains { $0.path == sessions.path })

        let result = RegenerableCleanupService.moveToTrash(
            .developerCaches,
            homeURL: root,
            worktrees: [],
            isCodexRunning: { false },
            trash: { source in
                let destination = trash.appendingPathComponent(source.lastPathComponent, isDirectory: true)
                try FileManager.default.moveItem(at: source, to: destination)
                return destination
            }
        )

        #expect(result.failures.isEmpty)
        #expect(result.trashedPaths == [cache.path])
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        #expect(FileManager.default.fileExists(atPath: sessions.appendingPathComponent("rollout.jsonl").path))
    }

    @Test func blocksCodexCachesWhileCodexIsRunningButLeavesNpmEligible() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let npm = root.appendingPathComponent(".npm/_cacache", isDirectory: true)
        let runtimes = root.appendingPathComponent(".cache/codex-runtimes", isDirectory: true)
        try FileManager.default.createDirectory(at: npm, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtimes, withIntermediateDirectories: true)
        try Data("npm".utf8).write(to: npm.appendingPathComponent("index"))
        try Data("runtime".utf8).write(to: runtimes.appendingPathComponent("bin"))

        let snapshot = RegenerableCleanupService.scan(homeURL: root, worktrees: [], isCodexRunning: true)
        let npmItem = snapshot.caches.first { $0.path == npm.path }
        let runtimeItem = snapshot.caches.first { $0.path == runtimes.path }
        #expect(npmItem?.isEligible == true)
        #expect(runtimeItem?.isEligible == false)
        #expect(runtimeItem?.blockedReason == "Quit Codex to clean this cache")

        let result = RegenerableCleanupService.moveToTrash(
            .developerCaches,
            homeURL: root,
            worktrees: [],
            isCodexRunning: { true },
            trash: { source in
                try FileManager.default.removeItem(at: source)
                return source
            }
        )

        #expect(result.trashedPaths == [npm.path])
        #expect(FileManager.default.fileExists(atPath: runtimes.appendingPathComponent("bin").path))
    }

    @Test func refusesAPathOutsideTheAllowlist() {
        let result = RegenerableCleanupService.moveToTrash(
            .developerCaches,
            homeURL: FileManager.default.temporaryDirectory,
            worktrees: [],
            isCodexRunning: { false },
            trash: { _ in
                Issue.record("Trash must not be called for an empty allowlist scan")
                return nil
            }
        )
        #expect(result.trashedPaths.isEmpty)
        #expect(result.failures.contains { $0.message == RegenerableCleanupError.nothingEligible.localizedDescription })
    }

    @Test func trashesGitignoredNodeModulesInInactiveWorktrees() throws {
        let fixture = try makeWorktreeFixture(gitignore: "node_modules\n")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let nodeModules = fixture.worktree.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try Data("left-pad".utf8).write(to: nodeModules.appendingPathComponent("index.js"))
        try Data("source".utf8).write(to: fixture.worktree.appendingPathComponent("app.js"))

        let record = worktreeRecord(path: fixture.worktree.path, repository: fixture.repository.path, active: false)
        let snapshot = RegenerableCleanupService.scan(homeURL: fixture.root, worktrees: [record], isCodexRunning: false)
        #expect(snapshot.eligibleItems(in: .worktreeDependencies).contains { $0.path == nodeModules.path })

        let result = RegenerableCleanupService.moveToTrash(
            .worktreeDependencies,
            homeURL: fixture.root,
            worktrees: [record],
            trash: { source in
                try FileManager.default.removeItem(at: source)
                return source
            }
        )

        #expect(result.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: nodeModules.path))
        #expect(FileManager.default.fileExists(atPath: fixture.worktree.appendingPathComponent("app.js").path))
    }

    @Test func protectsTrackedNodeModulesAndActiveWorktrees() throws {
        let fixture = try makeWorktreeFixture(gitignore: "")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let tracked = fixture.worktree.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: tracked, withIntermediateDirectories: true)
        try Data("tracked".utf8).write(to: tracked.appendingPathComponent("pkg.js"))

        let inactive = worktreeRecord(path: fixture.worktree.path, repository: fixture.repository.path, active: false)
        let inactiveSnapshot = RegenerableCleanupService.scan(homeURL: fixture.root, worktrees: [inactive], isCodexRunning: false)
        #expect(inactiveSnapshot.dependencies.first?.isEligible == false)
        #expect(inactiveSnapshot.dependencies.first?.blockedReason == "node_modules is not gitignored in this worktree")

        let active = worktreeRecord(path: fixture.worktree.path, repository: fixture.repository.path, active: true)
        let activeSnapshot = RegenerableCleanupService.scan(homeURL: fixture.root, worktrees: [active], isCodexRunning: false)
        #expect(activeSnapshot.dependencies.isEmpty)
        #expect(activeSnapshot.skippedActiveWorktrees == 1)

        let result = RegenerableCleanupService.moveToTrash(
            .worktreeDependencies,
            homeURL: fixture.root,
            worktrees: [active],
            trash: { _ in
                Issue.record("Trash must not run for an active worktree")
                return nil
            }
        )
        #expect(result.trashedPaths.isEmpty)
        #expect(FileManager.default.fileExists(atPath: tracked.appendingPathComponent("pkg.js").path))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentSpaceRegenerableCleanupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeWorktreeFixture(gitignore: String) throws -> (root: URL, repository: URL, worktree: URL) {
        let root = try temporaryDirectory()
        let repository = root.appendingPathComponent("repository", isDirectory: true)
        let worktree = root.appendingPathComponent("worktree", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try git(repository, ["init", "-b", "main"])
        try git(repository, ["config", "user.name", "CleanMyAgent Tests"])
        try git(repository, ["config", "user.email", "agent-space@example.test"])
        try Data("initial".utf8).write(to: repository.appendingPathComponent("README.md"))
        try Data(gitignore.utf8).write(to: repository.appendingPathComponent(".gitignore"))
        try git(repository, ["add", "README.md", ".gitignore"])
        try git(repository, ["commit", "-m", "initial"])
        try git(repository, ["worktree", "add", "-b", "codex/feature", worktree.path, "main"])
        return (root, repository, worktree)
    }

    private func worktreeRecord(path: String, repository: String, active: Bool) -> WorktreeRecord {
        WorktreeRecord(
            path: path,
            repositoryPath: repository,
            repository: URL(fileURLWithPath: repository).lastPathComponent,
            branch: "codex/feature",
            head: "abc123",
            bytes: 0,
            isDirty: true,
            hasUntrackedFiles: false,
            hasUnpushedCommits: true,
            hasActiveProcesses: active,
            statusKnown: true,
            isBare: false,
            isLocked: false,
            pullRequest: .none,
            safety: .protected,
            safetyReason: "unmerged on purpose"
        )
    }

    @discardableResult
    private func git(_ repository: URL, _ arguments: [String]) throws -> String {
        let result = Shell.run("/usr/bin/git", ["-C", repository.path] + arguments, timeout: 10)
        guard result.status == 0 else {
            throw RegenerableTestCommandError.failed(result.stderr)
        }
        return result.stdout
    }
}

private enum RegenerableTestCommandError: Error {
    case failed(String)
}
