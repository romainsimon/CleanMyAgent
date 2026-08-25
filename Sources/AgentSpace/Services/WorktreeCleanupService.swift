import Foundation

enum WorktreeCleanupError: LocalizedError, Equatable {
    case nothingSelected
    case noLongerRegistered
    case noLongerSafe(String)
    case removalFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingSelected:
            "Select at least one verified worktree."
        case .noLongerRegistered:
            "The worktree is no longer registered with its repository. Refresh the audit."
        case let .noLongerSafe(reason):
            "The worktree changed after the audit and is now protected: \(reason)"
        case let .removalFailed(message):
            "Git refused to remove the worktree: \(message)"
        }
    }
}

enum WorktreeCleanupService {
    static func remove(
        _ records: [WorktreeRecord],
        pullRequestLookup: WorktreeScanner.PullRequestLookup? = nil
    ) -> WorktreeCleanupResult {
        guard !records.isEmpty else {
            return WorktreeCleanupResult(
                removedPaths: [],
                reclaimedBytes: 0,
                failures: [WorktreeCleanupFailure(path: "", message: WorktreeCleanupError.nothingSelected.localizedDescription)]
            )
        }

        var removedPaths: [String] = []
        var reclaimedBytes: Int64 = 0
        var failures: [WorktreeCleanupFailure] = []

        for (repositoryPath, repositoryRecords) in Dictionary(grouping: records, by: \.repositoryPath) {
            let freshRecords: [WorktreeRecord]
            if let pullRequestLookup {
                freshRecords = WorktreeScanner.scan(
                    repositoryPaths: [repositoryPath],
                    includeSizes: false,
                    pullRequestLookup: pullRequestLookup
                )
            } else {
                freshRecords = WorktreeScanner.scan(repositoryPaths: [repositoryPath], includeSizes: false)
            }
            let freshByPath = Dictionary(uniqueKeysWithValues: freshRecords.map { ($0.path, $0) })

            for record in repositoryRecords {
                guard let fresh = freshByPath[record.path] else {
                    failures.append(WorktreeCleanupFailure(
                        path: record.path,
                        message: WorktreeCleanupError.noLongerRegistered.localizedDescription
                    ))
                    continue
                }
                guard fresh.safety == .removable else {
                    failures.append(WorktreeCleanupFailure(
                        path: record.path,
                        message: WorktreeCleanupError.noLongerSafe(fresh.safetyReason).localizedDescription
                    ))
                    continue
                }

                let removal = Shell.run(
                    "/usr/bin/git",
                    ["-C", repositoryPath, "worktree", "remove", "--", record.path],
                    timeout: 30
                )
                guard removal.status == 0 else {
                    let detail = removal.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    failures.append(WorktreeCleanupFailure(
                        path: record.path,
                        message: WorktreeCleanupError.removalFailed(detail.isEmpty ? "Unknown Git error" : detail).localizedDescription
                    ))
                    continue
                }

                removedPaths.append(record.path)
                reclaimedBytes += record.bytes
            }

            _ = Shell.run("/usr/bin/git", ["-C", repositoryPath, "worktree", "prune"], timeout: 10)
        }

        return WorktreeCleanupResult(
            removedPaths: removedPaths.sorted(),
            reclaimedBytes: reclaimedBytes,
            failures: failures
        )
    }
}
