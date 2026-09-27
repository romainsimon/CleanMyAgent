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
        targetPaths: Set<String>? = nil,
        activeWorkingDirectories suppliedActiveWorkingDirectories: Set<String>? = nil,
        activityLookup: @Sendable () -> Set<String>? = loadActiveWorkingDirectories,
        pullRequestLookup: PullRequestLookup = loadPullRequests
    ) -> [WorktreeRecord] {
        let repositoryPaths = suppliedRepositoryPaths ?? discoverRepositories()
        let activeWorkingDirectories = suppliedActiveWorkingDirectories ?? activityLookup()
        var records: [String: WorktreeRecord] = [:]

        for discoveredRepositoryPath in Set(repositoryPaths).sorted() {
            let repositoryPath = URL(fileURLWithPath: discoveredRepositoryPath).resolvingSymlinksInPath().path
            let listing = Shell.run("/usr/bin/git", ["-C", repositoryPath, "worktree", "list", "--porcelain", "-z"], timeout: 5)
            guard listing.status == 0 else { continue }

            let defaultReference = defaultBranchReference(repositoryPath: repositoryPath)
            let pullRequests = pullRequestLookup(repositoryPath)

            for partial in parse(listing.stdout) {
                let worktreePath = URL(fileURLWithPath: partial.path).resolvingSymlinksInPath().path
                guard !worktreePath.isEmpty,
                      worktreePath != repositoryPath,
                      records[worktreePath] == nil,
                      targetPaths == nil || targetPaths!.contains(worktreePath) else { continue }

                let status = Shell.run(
                    "/usr/bin/git",
                    ["-C", worktreePath, "status", "--porcelain=v1", "--untracked-files=all"],
                    timeout: 5
                )
                let statusKnown = status.status == 0
                let statusLines = status.stdout.split(separator: "\n").map(String.init)
                let hasUntrackedFiles = statusLines.contains { $0.hasPrefix("??") }
                let isDirty = statusKnown && !statusLines.isEmpty
                let hasActiveProcesses = activeWorkingDirectories?.contains {
                    $0 == worktreePath || $0.hasPrefix(worktreePath + "/")
                } ?? true
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
                let ignoredFilesProtected = hasUniqueIgnoredContent(worktreePath: worktreePath, repositoryPath: repositoryPath)
                let safety = safetyAssessment(
                    partial: partial,
                    statusKnown: statusKnown,
                    processStatusKnown: activeWorkingDirectories != nil,
                    ignoredFilesProtected: ignoredFilesProtected,
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
        let devRoot = ScanConfiguration.developmentRoot
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

        for line in output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init) {
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

        for reference in ["refs/remotes/origin/main", "refs/remotes/origin/master"] {
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
        processStatusKnown: Bool,
        ignoredFilesProtected: Bool,
        isDirty: Bool,
        hasUntrackedFiles: Bool,
        hasUnpushedCommits: Bool,
        hasActiveProcesses: Bool,
        isIntegrated: Bool,
        pullRequest: WorktreePullRequest
    ) -> (status: WorktreeSafety, reason: String) {
        if partial.isBare { return (.protected, "Bare repository metadata is never removed") }
        if partial.isLocked { return (.protected, "Git marked this worktree as locked") }
        if !processStatusKnown { return (.protected, "Process activity could not be verified") }
        if ignoredFilesProtected { return (.protected, "Contains ignored files or folders without a verified copy in the primary checkout") }
        if hasActiveProcesses { return (.protected, "A running process is using this worktree") }
        if !statusKnown { return (.protected, "Working-tree status could not be verified") }
        if hasUntrackedFiles { return (.protected, "Contains untracked files") }
        if isDirty { return (.protected, "Contains uncommitted changes") }
        if hasUnpushedCommits { return (.protected, "Contains commits not verified on a remote") }
        if pullRequest.state == .open { return (.protected, "Its pull request is still open") }
        if pullRequest.state == .unknown { return (.protected, "Pull-request state could not be verified") }
        if isIntegrated { return (.removable, "HEAD is already contained in the default branch") }
        if pullRequest.state == .merged && pullRequest.headOID == partial.head { return (.removable, "This exact HEAD belongs to a merged pull request") }
        if pullRequest.state == .closed { return (.protected, "Its pull request was closed without a verified merge") }
        return (.protected, "The branch is not verified as merged")
    }

    static func loadActiveWorkingDirectories() -> Set<String>? {
        let result = Shell.run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-Fn"], timeout: 8)
        guard result.status == 0 else { return nil }
        return Set(result.stdout.split(separator: "\n").compactMap { line in
            guard line.first == "n" else { return nil }
            let path = String(line.dropFirst())
            guard path.hasPrefix("/") else { return nil }
            return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        })
    }

    // Ignored files are invisible to normal git status. Protect every unique ignored item.
    // Directories stay protected; dependencies can be reviewed and trashed separately.
    private static func hasUniqueIgnoredContent(worktreePath: String, repositoryPath: String) -> Bool {
        let result = Shell.run("/usr/bin/git", ["-C", worktreePath, "ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z"], timeout: 5)
        guard result.status == 0 else { return true }
        for relative in result.stdout.split(separator: "\0").map(String.init) {
            let source = URL(fileURLWithPath: worktreePath).appendingPathComponent(relative).standardizedFileURL
            let copy = URL(fileURLWithPath: repositoryPath).appendingPathComponent(relative).standardizedFileURL
            guard source.path.hasPrefix(worktreePath + "/"), copy.path.hasPrefix(repositoryPath + "/"),
                  let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  FileManager.default.contentsEqual(atPath: source.path, andPath: copy.path) else { return true }
        }
        return false
    }

    private struct Connection: Decodable { let nodes: [GitHubPullRequest] }
    private struct GraphQLData: Decodable { let repository: [String: Connection]? }
    private struct GraphQLResponse: Decodable { let data: GraphQLData? }

    private static func loadPullRequests(repositoryPath: String) -> PullRequestIndex {
        guard let slug = githubSlug(repositoryPath: repositoryPath), let gh = githubExecutable() else { return .unavailable }
        let listing = Shell.run("/usr/bin/git", ["-C", repositoryPath, "worktree", "list", "--porcelain", "-z"], timeout: 5)
        guard listing.status == 0 else { return .unavailable }
        let branches = Array(Set(parse(listing.stdout).filter { $0.path != repositoryPath && $0.branch != "Detached HEAD" }
            .map { $0.branch.replacingOccurrences(of: "refs/heads/", with: "") })).sorted()
        guard branches.count <= 100 else { return .unavailable }
        if branches.isEmpty { return PullRequestIndex(isAvailable: true, byBranch: [:]) }
        func quoted(_ value: String) -> String { String(data: try! JSONEncoder().encode(value), encoding: .utf8)! }
        let parts = slug.split(separator: "/").map(String.init)
        let fields = "nodes { headRefName headRefOid state mergedAt url }"
        let queries = branches.enumerated().map { index, branch in
            "open\(index): pullRequests(headRefName: \(quoted(branch)), first: 1, states: [OPEN]) { \(fields) } latest\(index): pullRequests(headRefName: \(quoted(branch)), first: 1, orderBy: {field: CREATED_AT, direction: DESC}) { \(fields) }"
        }.joined(separator: " ")
        let query = "query { repository(owner: \(quoted(parts[0])), name: \(quoted(parts[1]))) { \(queries) } }"
        let result = Shell.run(gh, ["api", "graphql", "-f", "query=\(query)"], environment: ["GH_PROMPT_DISABLED": "1"], timeout: 15)
        guard result.status == 0, let data = result.stdout.data(using: .utf8),
              let connections = try? JSONDecoder().decode(GraphQLResponse.self, from: data).data?.repository else { return .unavailable }
        var byBranch: [String: WorktreePullRequest] = [:]
        for (index, branch) in branches.enumerated() {
            guard let open = connections["open\(index)"], let latest = connections["latest\(index)"] else { return .unavailable }
            guard let pr = open.nodes.first ?? latest.nodes.first else { continue }
            let state: WorktreePullRequestState = pr.state == "OPEN" ? .open : ((pr.mergedAt != nil || pr.state == "MERGED") ? .merged : .closed)
            byBranch[branch] = WorktreePullRequest(state: state, url: pr.url, headOID: pr.headRefOid)
        }
        return PullRequestIndex(isAvailable: true, byBranch: byBranch)
    }

    static func githubExecutable() -> String? {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").filter { $0.hasPrefix("/") }.map { String($0) + "/gh" }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
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
