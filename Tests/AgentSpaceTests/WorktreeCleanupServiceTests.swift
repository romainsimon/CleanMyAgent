import Foundation
import Testing
@testable import AgentSpace

struct WorktreeCleanupServiceTests {
    @Test func removesOnlyARevalidatedIntegratedWorktreeAndKeepsItsBranch() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("merged-worktree", isDirectory: true)
        try git(fixture.repository, ["worktree", "add", "-b", "codex/merged", worktree.path, "main"])

        let auditedPath = worktree.resolvingSymlinksInPath().path
        let record = try #require(scan(fixture.repository).first { $0.path == auditedPath })
        #expect(record.safety == .removable)

        let result = WorktreeCleanupService.remove([record], pullRequestLookup: noPullRequests)

        #expect(result.removedPaths == [auditedPath])
        #expect(result.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: worktree.path))
        #expect(try git(fixture.repository, ["branch", "--list", "codex/merged"]).contains("codex/merged"))
    }

    @Test func blocksAnUntrackedFileAndLeavesTheWorktreeUntouched() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("dirty-worktree", isDirectory: true)
        try git(fixture.repository, ["worktree", "add", "-b", "codex/dirty", worktree.path, "main"])
        try Data("valuable local note".utf8).write(to: worktree.appendingPathComponent("notes.txt"))

        let auditedPath = worktree.resolvingSymlinksInPath().path
        let record = try #require(scan(fixture.repository).first { $0.path == auditedPath })
        #expect(record.safety == .protected)
        #expect(record.hasUntrackedFiles)

        let result = WorktreeCleanupService.remove([record], pullRequestLookup: noPullRequests)

        #expect(result.removedPaths.isEmpty)
        #expect(result.failures.count == 1)
        #expect(FileManager.default.fileExists(atPath: worktree.appendingPathComponent("notes.txt").path))
    }

    @Test func blocksALocalCommitThatIsNotVerifiedOnARemote() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("unpushed-worktree", isDirectory: true)
        try git(fixture.repository, ["worktree", "add", "-b", "codex/unpushed", worktree.path, "main"])
        try Data("local commit".utf8).write(to: worktree.appendingPathComponent("README.md"))
        try git(worktree, ["add", "README.md"])
        try git(worktree, ["commit", "-m", "local only"])

        let auditedPath = worktree.resolvingSymlinksInPath().path
        let record = try #require(scan(fixture.repository).first { $0.path == auditedPath })
        #expect(record.safety == .protected)
        #expect(record.hasUnpushedCommits)

        let result = WorktreeCleanupService.remove([record], pullRequestLookup: noPullRequests)

        #expect(result.removedPaths.isEmpty)
        #expect(FileManager.default.fileExists(atPath: worktree.path))
    }

    @Test func protectsAnOpenPullRequestEvenWhenItsHeadIsOtherwiseIntegrated() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("open-pr-worktree", isDirectory: true)
        try git(fixture.repository, ["worktree", "add", "-b", "codex/open-pr", worktree.path, "main"])
        let head = try git(worktree, ["rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)

        let records = WorktreeScanner.scan(
            repositoryPaths: [fixture.repository.path],
            includeSizes: false,
            pullRequestLookup: { _ in
                WorktreeScanner.PullRequestIndex(
                    isAvailable: true,
                    byBranch: [
                        "codex/open-pr": WorktreePullRequest(state: .open, url: "https://example.test/pr/1", headOID: head)
                    ]
                )
            }
        )
        let auditedPath = worktree.resolvingSymlinksInPath().path
        let record = try #require(records.first { $0.path == auditedPath })

        #expect(record.safety == .protected)
        #expect(record.safetyReason.localizedCaseInsensitiveContains("open"))
    }

    @Test func protectsAWorktreeUsedByARunningProcess() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("active-worktree", isDirectory: true)
        try git(fixture.repository, ["worktree", "add", "-b", "codex/active", worktree.path, "main"])
        let auditedPath = worktree.resolvingSymlinksInPath().path

        let records = WorktreeScanner.scan(
            repositoryPaths: [fixture.repository.path],
            includeSizes: false,
            activeWorkingDirectories: [auditedPath],
            pullRequestLookup: noPullRequests
        )
        let record = try #require(records.first { $0.path == auditedPath })

        #expect(record.safety == .protected)
        #expect(record.hasActiveProcesses)
        #expect(record.safetyReason.localizedCaseInsensitiveContains("running process"))
    }

    @Test func acceptsAMergedPullRequestOnlyAtTheAuditedRemoteHead() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("squash-merged-worktree", isDirectory: true)
        try git(fixture.repository, ["worktree", "add", "-b", "codex/squash-merged", worktree.path, "main"])
        try Data("merged elsewhere".utf8).write(to: worktree.appendingPathComponent("README.md"))
        try git(worktree, ["add", "README.md"])
        try git(worktree, ["commit", "-m", "feature head"])
        let head = try git(worktree, ["rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)

        let records = WorktreeScanner.scan(
            repositoryPaths: [fixture.repository.path],
            includeSizes: false,
            pullRequestLookup: { _ in
                WorktreeScanner.PullRequestIndex(
                    isAvailable: true,
                    byBranch: [
                        "codex/squash-merged": WorktreePullRequest(state: .merged, url: "https://example.test/pr/2", headOID: head)
                    ]
                )
            }
        )
        let auditedPath = worktree.resolvingSymlinksInPath().path
        let record = try #require(records.first { $0.path == auditedPath })

        #expect(record.safety == .removable)
        #expect(!record.hasUnpushedCommits)
    }

    private func scan(_ repository: URL) -> [WorktreeRecord] {
        WorktreeScanner.scan(
            repositoryPaths: [repository.path],
            includeSizes: false,
            pullRequestLookup: noPullRequests
        )
    }

    private var noPullRequests: WorktreeScanner.PullRequestLookup {
        { _ in WorktreeScanner.PullRequestIndex(isAvailable: true, byBranch: [:]) }
    }

    private func makeRepositoryFixture() throws -> (root: URL, repository: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentSpaceWorktreeTests-\(UUID().uuidString)", isDirectory: true)
        let repository = root.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try git(repository, ["init", "-b", "main"])
        try git(repository, ["config", "user.name", "CleanMyAgent Tests"])
        try git(repository, ["config", "user.email", "agent-space@example.test"])
        try Data("initial".utf8).write(to: repository.appendingPathComponent("README.md"))
        try git(repository, ["add", "README.md"])
        try git(repository, ["commit", "-m", "initial"])
        return (root, repository)
    }

    @discardableResult
    private func git(_ repository: URL, _ arguments: [String]) throws -> String {
        let result = Shell.run("/usr/bin/git", ["-C", repository.path] + arguments, timeout: 10)
        guard result.status == 0 else {
            throw TestCommandError.failed(result.stderr)
        }
        return result.stdout
    }
}

private enum TestCommandError: Error {
    case failed(String)
}
