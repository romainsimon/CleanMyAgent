import AppKit
import Foundation

enum ArchiveCleanupError: LocalizedError, Equatable {
    case codexIsRunning
    case invalidTarget
    case symbolicLink
    case nothingToClean

    var errorDescription: String? {
        switch self {
        case .codexIsRunning:
            "Quit Codex before moving its archived sessions to the Trash."
        case .invalidTarget:
            "Agent Space refused the cleanup because the archive path was not the expected Codex folder."
        case .symbolicLink:
            "Agent Space refused the cleanup because the archive folder is a symbolic link."
        case .nothingToClean:
            "There are no archived Codex sessions to clean."
        }
    }
}

enum ArchiveCleanupService {
    typealias TrashOperation = @Sendable (URL) throws -> URL?
    typealias RunningCheck = @Sendable () -> Bool

    static func scan(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> CleanupTargetSnapshot {
        let target = archiveURL(homeURL: homeURL)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) && isDirectory.boolValue
        guard exists else {
            return CleanupTargetSnapshot(path: target.path, bytes: 0, fileCount: 0, exists: false, capturedAt: Date())
        }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        let enumerator = FileManager.default.enumerator(
            at: target,
            includingPropertiesForKeys: keys,
            options: options
        )
        var fileCount = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            if (try? fileURL.resourceValues(forKeys: Set(keys)).isRegularFile) == true {
                fileCount += 1
            }
        }

        return CleanupTargetSnapshot(
            path: target.path,
            bytes: Shell.directoryBytes(at: target.path),
            fileCount: fileCount,
            exists: true,
            capturedAt: Date()
        )
    }

    static func moveToTrash(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        isCodexRunning: RunningCheck = systemCodexRunningCheck,
        trash: TrashOperation = systemTrash
    ) throws -> URL? {
        guard !isCodexRunning() else { throw ArchiveCleanupError.codexIsRunning }

        let target = archiveURL(homeURL: homeURL)
        let expected = homeURL
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("archived_sessions", isDirectory: true)
            .standardizedFileURL
        guard target.standardizedFileURL == expected else { throw ArchiveCleanupError.invalidTarget }

        let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values?.isSymbolicLink != true else { throw ArchiveCleanupError.symbolicLink }
        guard values?.isDirectory == true else { throw ArchiveCleanupError.nothingToClean }
        guard scan(homeURL: homeURL).fileCount > 0 else { throw ArchiveCleanupError.nothingToClean }

        let trashedURL = try trash(target)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return trashedURL
    }

    private static func archiveURL(homeURL: URL) -> URL {
        homeURL
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("archived_sessions", isDirectory: true)
            .standardizedFileURL
    }

    private static func systemTrash(_ url: URL) throws -> URL? {
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }

    private static func systemCodexRunningCheck() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").isEmpty
    }
}
