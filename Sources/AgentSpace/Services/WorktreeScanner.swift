import Foundation

enum WorktreeScanner {
    struct PullRequestIndex: Sendable {
        let isAvailable: Bool
        let byBranch: [String: WorktreePullRequest]

        static let unavailable = PullRequestIndex(isAvailable: false, byBranch: [:])
    }

    typealias PullRequestLookup = @Sendable (_ repositoryPath: String) -> PullRequestIndex

    private struct Partial {
        var path = ""
        var head = ""
        var branch = "Detached HEAD"
        var isBare = false
        var isLocked = false
    }

    private struct GitHubPullRequest: Decodable {
        let headRefName: String
        let headRefOid: String?
        let state: String
        let mergedAt: String?
        let url: String?
    }

    static func scan(
        repositoryPaths suppliedRepositoryPaths: [String]? = nil,
        includeSizes: Bool = true,
        activeWorkingDirectories suppliedActiveWorkingDirectories: Set<String>? = nil,
        pullRequestLookup: PullRequestLookup = loadPullRequests
    ) -> [WorktreeRecord] {
        let repositoryPaths = suppliedRepositoryPaths ?? discoverRepositories()
        let activeWorkingDirectories = suppliedActiveWorkingDirectories ?? loadActiveWorkingDirectories()
        var records: [String: WorktreeRecord] = [:]

        for discoveredRepositoryPath in Set(repositoryPaths).sorted() {
            let repositoryPath = URL(fileURLWithPath: discoveredRepositoryPath).resolvingSymlinksInPath().path
            let listing = Shell.run("/usr/bin/git", ["-C", repositoryPath, "worktree", "list", "--porcelain"], timeout: 5)
            guard listing.status == 0 else { continue }

            let defaultReference = defaultBranchReference(repositoryPath: repositoryPath)
            let pullRequests = pullRequestLookup(repositoryPath)

            for partial in parse(listing.stdout) {
                let worktreePath = URL(fileURLWithPath: partial.path).resolvingSymlinksInPath().path
                guard !worktreePath.isEmpty,
                      worktreePath != repositoryPath,
                      records[worktreePath] == nil else { continue }

                let status = Shell.run(
                    "/usr/bin/git",
                    ["-C", worktreePath, "status", "--porcelain=v1", "--untracked-files=all"],
                    timeout: 5
                )
                let statusKnown = status.status == 0
                let statusLines = status.stdout.split(separator: "\n").map(String.init)
                let hasUntrackedFiles = statusLines.contains { $0.hasPrefix("??") }
                let isDirty = statusKnown && !statusLines.isEmpty
                let hasActiveProcesses = activeWorkingDirectories.contains {
                    $0 == worktreePath || $0.hasPrefix(worktreePath + "/")
                }
                let branch = partial.branch.replacingOccurrences(of: "refs/heads/", with: "")
                let pullRequest: WorktreePullRequest
                if branch == "Detached HEAD" {
                    pullRequest = pullRequests.isAvailable ? .none : .unknown
                } else {
                    pullRequest = pullRequests.isAvailable
                        ? (pullRequests.byBranch[branch] ?? .none)
                        : .unknown
                }
                let isIntegrated = isAncestorOfDefault(
                    repositoryPath: repositoryPath,
                    head: partial.head,
                    defaultReference: defaultReference
                )
                let hasUnpushedCommits = localCommitsAreUnpushed(
                    worktreePath: worktreePath,
                    head: partial.head,
                    isIntegrated: isIntegrated,
                    pullRequest: pullRequest
                )
                let safety = safetyAssessment(
                    partial: partial,
                    statusKnown: statusKnown,
                    isDirty: isDirty,
                    hasUntrackedFiles: hasUntrackedFiles,
                    hasUnpushedCommits: hasUnpushedCommits,
                    hasActiveProcesses: hasActiveProcesses,
                    isIntegrated: isIntegrated,
                    pullRequest: pullRequest
                )

                records[worktreePath] = WorktreeRecord(
                    path: worktreePath,
                    repositoryPath: repositoryPath,
                    repository: URL(fileURLWithPath: repositoryPath).lastPathComponent,
                    branch: branch,
                    head: partial.head,
                    bytes: includeSizes ? Shell.directoryBytes(at: worktreePath) : 0,
                    isDirty: isDirty,
                    hasUntrackedFiles: hasUntrackedFiles,
                    hasUnpushedCommits: hasUnpushedCommits,
                    hasActiveProcesses: hasActiveProcesses,
                    statusKnown: statusKnown,
                    isBare: partial.isBare,
                    isLocked: partial.isLocked,
                    pullRequest: pullRequest,
                    safety: safety.status,
                    safetyReason: safety.reason
                )
            }
        }

        return records.values.sorted {
            if $0.safety != $1.safety { return $0.safety == .removable }
            if $0.repository == $1.repository { return $0.path < $1.path }
            return $0.repository.localizedCaseInsensitiveCompare($1.repository) == .orderedAscending
        }
    }

    private static func discoverRepositories() -> [String] {
        let devRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("dev", isDirectory: true).path
        guard FileManager.default.fileExists(atPath: devRoot) else { return [] }

        let find = Shell.run(
            "/usr/bin/find",
            [devRoot, "-maxdepth", "3", "-name", ".git", "-type", "d", "-prune"],
            timeout: 20
        )
        guard find.status == 0 else { return [] }
        return find.stdout.split(separator: "\n").map {
            URL(fileURLWithPath: String($0)).deletingLastPathComponent().path
        }
    }

    private static func parse(_ output: String) -> [Partial] {
        var partials: [Partial] = []
        var partial = Partial()

        func commit() {
            guard !partial.path.isEmpty else { return }
            partials.append(partial)
            partial = Partial()
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.isEmpty {
                commit()
            } else if line.hasPrefix("worktree ") {
                if !partial.path.isEmpty { commit() }
                partial.path = String(line.dropFirst("worktree ".count))
            } else if line.hasPrefix("HEAD ") {
                partial.head = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                partial.branch = String(line.dropFirst("branch ".count))
            } else if line == "bare" {
                partial.isBare = true
            } else if line.hasPrefix("locked") {
                partial.isLocked = true
            }
        }
        commit()
        return partials
    }

    private static func defaultBranchReference(repositoryPath: String) -> String? {
        let symbolic = Shell.run(
            "/usr/bin/git",
            ["-C", repositoryPath, "symbolic-ref", "refs/remotes/origin/HEAD"],
            timeout: 3
        )
        if symbolic.status == 0 {
            let reference = symbolic.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reference.isEmpty { return reference }
        }

        for reference in ["refs/remotes/origin/main", "refs/remotes/origin/master", "refs/heads/main", "refs/heads/master"] {
            let exists = Shell.run(
                "/usr/bin/git",
                ["-C", repositoryPath, "rev-parse", "--verify", "--quiet", reference],
                timeout: 3
            )
            if exists.status == 0 { return reference }
        }
        return nil
    }

    private static func isAncestorOfDefault(
        repositoryPath: String,
        head: String,
        defaultReference: String?
    ) -> Bool {
        guard !head.isEmpty, let defaultReference else { return false }
        return Shell.run(
            "/usr/bin/git",
            ["-C", repositoryPath, "merge-base", "--is-ancestor", head, defaultReference],
            timeout: 5
        ).status == 0
    }

    private static func localCommitsAreUnpushed(
        worktreePath: String,
        head: String,
        isIntegrated: Bool,
        pullRequest: WorktreePullRequest
    ) -> Bool {
        if isIntegrated { return false }

        let upstream = Shell.run(
            "/usr/bin/git",
            ["-C", worktreePath, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            timeout: 3
        )
        if upstream.status == 0 {
            let upstreamName = upstream.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let ahead = Shell.run(
                "/usr/bin/git",
                ["-C", worktreePath, "rev-list", "--count", "\(upstreamName)..HEAD"],
                timeout: 5
            )
            guard ahead.status == 0,
                  let count = Int(ahead.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) else { return true }
            return count > 0
        }

        let remoteContains = Shell.run(
            "/usr/bin/git",
            ["-C", worktreePath, "branch", "-r", "--contains", head, "--format=%(refname:short)"],
            timeout: 5
        )
        if remoteContains.status == 0,
           !remoteContains.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        return pullRequest.headOID != head
    }

    private static func safetyAssessment(
        partial: Partial,
        statusKnown: Bool,
        isDirty: Bool,
        hasUntrackedFiles: Bool,
        hasUnpushedCommits: Bool,
        hasActiveProcesses: Bool,
        isIntegrated: Bool,
        pullRequest: WorktreePullRequest
    ) -> (status: WorktreeSafety, reason: String) {
        if partial.isBare { return (.protected, "Bare repository metadata is never removed") }
        if partial.isLocked { return (.protected, "Git marked this worktree as locked") }
        if hasActiveProcesses { return (.protected, "A running process is using this worktree") }
        if !statusKnown { return (.protected, "Working-tree status could not be verified") }
        if hasUntrackedFiles { return (.protected, "Contains untracked files") }
        if isDirty { return (.protected, "Contains uncommitted changes") }
        if hasUnpushedCommits { return (.protected, "Contains commits not verified on a remote") }
        if pullRequest.state == .open { return (.protected, "Its pull request is still open") }
        if pullRequest.state == .unknown { return (.protected, "Pull-request state could not be verified") }
        if isIntegrated { return (.removable, "HEAD is already contained in the default branch") }
        if pullRequest.state == .merged { return (.removable, "Its pull request is merged and the audited HEAD is remote-backed") }
        if pullRequest.state == .closed { return (.protected, "Its pull request was closed without a verified merge") }
        return (.protected, "The branch is not verified as merged")
    }

    private static func loadActiveWorkingDirectories() -> Set<String> {
        let result = Shell.run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-Fn"], timeout: 8)
        guard result.status == 0 else { return [] }
        return Set(result.stdout.split(separator: "\n").compactMap { line in
            guard line.first == "n" else { return nil }
            let path = String(line.dropFirst())
            guard path.hasPrefix("/") else { return nil }
            return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        })
    }

    private static func loadPullRequests(repositoryPath: String) -> PullRequestIndex {
        guard let slug = githubSlug(repositoryPath: repositoryPath) else { return .unavailable }
        let result = Shell.run(
            "/usr/bin/env",
            [
                "gh", "pr", "list",
                "--repo", slug,
                "--state", "all",
                "--limit", "200",
                "--json", "headRefName,headRefOid,state,mergedAt,url"
            ],
            environment: ["GH_PROMPT_DISABLED": "1"],
            timeout: 8
        )
        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let pullRequests = try? JSONDecoder().decode([GitHubPullRequest].self, from: data) else {
            return .unavailable
        }

        var byBranch: [String: WorktreePullRequest] = [:]
        for pullRequest in pullRequests {
            let state: WorktreePullRequestState
            if pullRequest.mergedAt != nil || pullRequest.state.uppercased() == "MERGED" {
                state = .merged
            } else if pullRequest.state.uppercased() == "OPEN" {
                state = .open
            } else {
                state = .closed
            }
            let candidate = WorktreePullRequest(
                state: state,
                url: pullRequest.url,
                headOID: pullRequest.headRefOid
            )
            if byBranch[pullRequest.headRefName]?.state != .open {
                byBranch[pullRequest.headRefName] = candidate
            }
        }
        return PullRequestIndex(isAvailable: true, byBranch: byBranch)
    }

    private static func githubSlug(repositoryPath: String) -> String? {
        let remote = Shell.run(
            "/usr/bin/git",
            ["-C", repositoryPath, "remote", "get-url", "origin"],
            timeout: 3
        )
        guard remote.status == 0 else { return nil }
        var value = remote.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("git@github.com:") {
            value.removeFirst("git@github.com:".count)
        } else if let range = value.range(of: "github.com/") {
            value = String(value[range.upperBound...])
        } else {
            return nil
        }
        if value.hasSuffix(".git") { value.removeLast(4) }
        let components = value.split(separator: "/")
        guard components.count == 2 else { return nil }
        return components.joined(separator: "/")
    }
}
