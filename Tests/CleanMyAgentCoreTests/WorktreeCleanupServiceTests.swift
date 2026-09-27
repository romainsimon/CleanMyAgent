import Foundation
import Testing
@testable import CleanMyAgentCore

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

    @Test func protectsUniqueIgnoredEnvironmentAndRevalidatesItAfterAudit() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data(".env\n".utf8).write(to: fixture.repository.appendingPathComponent(".gitignore"))
        try git(fixture.repository, ["add", ".gitignore"])
        try git(fixture.repository, ["commit", "-m", "ignore environment"])
        try git(fixture.repository, ["update-ref", "refs/remotes/origin/main", "HEAD"])
        let worktree = fixture.root.appendingPathComponent("ignored-worktree")
        try git(fixture.repository, ["worktree", "add", "-b", "codex/ignored", worktree.path, "main"])
        let record = try #require(scan(fixture.repository).first)
        #expect(record.safety == .removable)
        try Data("TEST_ONLY=preserve-me".utf8).write(to: worktree.appendingPathComponent(".env"))
        #expect(try git(worktree, ["status", "--porcelain"]).isEmpty)
        let protected = try #require(scan(fixture.repository).first)
        #expect(protected.safety == .protected)
        let result = WorktreeCleanupService.remove([record], pullRequestLookup: noPullRequests)
        #expect(result.removedPaths.isEmpty)
        #expect(FileManager.default.fileExists(atPath: worktree.appendingPathComponent(".env").path))
    }

    @Test func protectsUnknownProcessActivity() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("unknown-activity")
        try git(fixture.repository, ["worktree", "add", "-b", "codex/unknown", worktree.path, "main"])
        let record = try #require(WorktreeScanner.scan(repositoryPaths: [fixture.repository.path], includeSizes: false, activityLookup: { nil }, pullRequestLookup: noPullRequests).first)
        #expect(record.safety == .protected)
        #expect(record.safetyReason.contains("could not be verified"))
    }

    @Test func protectsReusedMergedBranchWithNewerPushedHead() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let worktree = fixture.root.appendingPathComponent("reused-branch")
        try git(fixture.repository, ["worktree", "add", "-b", "codex/reused", worktree.path, "main"])
        let mergedHead = try git(worktree, ["rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
        try Data("later feature".utf8).write(to: worktree.appendingPathComponent("README.md"))
        try git(worktree, ["add", "README.md"])
        try git(worktree, ["commit", "-m", "reuse merged branch"])
        try git(fixture.repository, ["remote", "add", "origin", "https://example.test/repository.git"])
        try git(worktree, ["update-ref", "refs/remotes/origin/codex/reused", "HEAD"])
        try git(worktree, ["branch", "--set-upstream-to=origin/codex/reused"])
        let record = try #require(WorktreeScanner.scan(repositoryPaths: [fixture.repository.path], includeSizes: false, activeWorkingDirectories: [], pullRequestLookup: { _ in
            WorktreeScanner.PullRequestIndex(isAvailable: true, byBranch: ["codex/reused": WorktreePullRequest(state: .merged, url: nil, headOID: mergedHead)])
        }).first)
        #expect(!record.hasUnpushedCommits)
        #expect(record.safety == .protected)
    }

    @Test func aLocalDefaultBranchDoesNotProveRemoteIntegration() throws {
        let fixture = try makeRepositoryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("not pushed".utf8).write(to: fixture.repository.appendingPathComponent("README.md"))
        try git(fixture.repository, ["add", "README.md"])
        try git(fixture.repository, ["commit", "-m", "local main change"])
        let worktree = fixture.root.appendingPathComponent("local-default")
        try git(fixture.repository, ["worktree", "add", "-b", "codex/local-default", worktree.path, "main"])
        let record = try #require(scan(fixture.repository).first)
        #expect(record.safety == .protected)
        #expect(record.hasUnpushedCommits)
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
            .appendingPathComponent("CleanMyAgentCoreWorktreeTests-\(UUID().uuidString)", isDirectory: true)
        let repository = root.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try git(repository, ["init", "-b", "main"])
        try git(repository, ["config", "user.name", "CleanMyAgent Tests"])
        try git(repository, ["config", "user.email", "agent-space@example.test"])
        try Data("initial".utf8).write(to: repository.appendingPathComponent("README.md"))
        try git(repository, ["add", "README.md"])
        try git(repository, ["commit", "-m", "initial"])
        try git(repository, ["update-ref", "refs/remotes/origin/main", "HEAD"])
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
