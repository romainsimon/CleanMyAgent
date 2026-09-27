import AppKit
import Foundation

enum ReleaseSmoke {
    static func run() -> Int32 {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CleanMyAgentSmoke-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            guard Bundle.main.resourceURL != nil else { throw SmokeError.failed("Bundle resources missing") }
            for agent in AgentKind.allCases where agent != .ori {
                guard AppResources.icon(for: agent) != nil else { throw SmokeError.failed("Packaged icon missing: \(agent.rawValue)") }
            }
            for section in AppSection.allCases {
                let glyph = "ph-\(PhosphorIcon.glyph(for: section.symbol))"
                guard AppResources.image(named: glyph) != nil else {
                    throw SmokeError.failed("Packaged navigation glyph missing: \(section.rawValue)")
                }
            }
            for name in ["hero-mascot", "protected-folder", "bento-storage", "bento-usage", "bento-performance", "bento-mac", "bento-dependencies", "bento-caches", "bento-archives"] {
                guard AppResources.image(named: name) != nil else {
                    throw SmokeError.failed("Packaged illustration missing: \(name)")
                }
            }
            let repository = root.appendingPathComponent("repository")
            let worktree = root.appendingPathComponent("worktree")
            try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
            func git(_ path: URL, _ arguments: [String]) throws {
                guard Shell.run("/usr/bin/git", ["-C", path.path] + arguments, environment: ["GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null"], timeout: 5).status == 0 else { throw SmokeError.failed("Fixture Git command failed") }
            }
            try git(repository, ["init", "-b", "main"])
            try git(repository, ["config", "user.name", "Smoke Test"])
            try git(repository, ["config", "user.email", "smoke@example.test"])
            try Data(".env\n".utf8).write(to: repository.appendingPathComponent(".gitignore"))
            try git(repository, ["add", ".gitignore"])
            try git(repository, ["commit", "-m", "fixture"])
            try git(repository, ["update-ref", "refs/remotes/origin/main", "HEAD"])
            try git(repository, ["worktree", "add", "-b", "codex/smoke", worktree.path, "main"])
            let lookup: WorktreeScanner.PullRequestLookup = { _ in .init(isAvailable: true, byBranch: [:]) }
            guard let clean = WorktreeScanner.scan(repositoryPaths: [repository.path], includeSizes: false, activeWorkingDirectories: [], pullRequestLookup: lookup).first, clean.safety == .removable else { throw SmokeError.failed("Clean fixture audit failed") }
            try Data("TEST_ONLY=preserved".utf8).write(to: worktree.appendingPathComponent(".env"))
            let removed = WorktreeCleanupService.remove([clean], pullRequestLookup: lookup)
            guard removed.removedPaths.isEmpty, FileManager.default.fileExists(atPath: worktree.appendingPathComponent(".env").path) else { throw SmokeError.failed("Ignored fixture was not protected") }
            print("Production runtime smoke passed: packaged assets, Git audit, cleanup revalidation, ignored-file preservation.")
            return 0
        } catch {
            fputs("Production runtime smoke failed: \(error)\n", stderr)
            return 1
        }
    }
    private enum SmokeError: Error { case failed(String) }
}
