import Foundation

enum WorktreeScanner {
    private struct Partial {
        var path = ""
        var head = ""
        var branch = "Detached HEAD"
        var isBare = false
        var isLocked = false
    }

    static func scan() -> [WorktreeRecord] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let devRoot = "\(home)/dev"
        guard FileManager.default.fileExists(atPath: devRoot) else { return [] }

        let find = Shell.run("/usr/bin/find", [devRoot, "-maxdepth", "3", "-name", ".git", "-type", "d", "-prune"])
        guard find.status == 0 else { return [] }
        let repositories = Set(
            find.stdout.split(separator: "\n").map { URL(fileURLWithPath: String($0)).deletingLastPathComponent().path }
        )

        var records: [String: WorktreeRecord] = [:]
        for repositoryPath in repositories.sorted() {
            let listing = Shell.run("/usr/bin/git", ["-C", repositoryPath, "worktree", "list", "--porcelain"])
            guard listing.status == 0 else { continue }
            var partial = Partial()

            func commit() {
                guard !partial.path.isEmpty,
                      partial.path != repositoryPath,
                      records[partial.path] == nil else {
                    partial = Partial()
                    return
                }
                let status = Shell.run(
                    "/usr/bin/git",
                    ["-C", partial.path, "diff-index", "--quiet", "HEAD", "--"],
                    timeout: 1
                )
                let statusKnown = status.status == 0 || status.status == 1
                records[partial.path] = WorktreeRecord(
                    path: partial.path,
                    repository: URL(fileURLWithPath: repositoryPath).lastPathComponent,
                    branch: partial.branch.replacingOccurrences(of: "refs/heads/", with: ""),
                    head: String(partial.head.prefix(8)),
                    bytes: 0,
                    isDirty: status.status == 1,
                    statusKnown: statusKnown,
                    isBare: partial.isBare,
                    isLocked: partial.isLocked
                )
                partial = Partial()
            }

            for line in listing.stdout.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
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
        }

        return records.values.sorted {
            if $0.repository == $1.repository { return $0.path < $1.path }
            return $0.repository.localizedCaseInsensitiveCompare($1.repository) == .orderedAscending
        }
    }
}
