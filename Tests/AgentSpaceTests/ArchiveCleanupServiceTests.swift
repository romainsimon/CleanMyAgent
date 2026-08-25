import Foundation
import Testing
@testable import AgentSpace

struct ArchiveCleanupServiceTests {
    @Test func movesOnlyArchivedSessionsAndRecreatesTheirDirectory() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let archived = root.appendingPathComponent(".codex/archived_sessions", isDirectory: true)
        let active = root.appendingPathComponent(".codex/sessions", isDirectory: true)
        let fakeTrash = root.appendingPathComponent("Fake Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeTrash, withIntermediateDirectories: true)
        try Data("archived".utf8).write(to: archived.appendingPathComponent("old.jsonl"))
        try Data("active".utf8).write(to: active.appendingPathComponent("current.jsonl"))

        let trashedURL = try ArchiveCleanupService.moveToTrash(
            homeURL: root,
            isCodexRunning: { false },
            trash: { source in
                let destination = fakeTrash.appendingPathComponent("archived_sessions", isDirectory: true)
                try FileManager.default.moveItem(at: source, to: destination)
                return destination
            }
        )

        #expect(trashedURL == fakeTrash.appendingPathComponent("archived_sessions", isDirectory: true))
        #expect(FileManager.default.fileExists(atPath: archived.path))
        #expect((try FileManager.default.contentsOfDirectory(atPath: archived.path)).isEmpty)
        #expect(FileManager.default.fileExists(atPath: active.appendingPathComponent("current.jsonl").path))
        #expect(FileManager.default.fileExists(atPath: fakeTrash.appendingPathComponent("archived_sessions/old.jsonl").path))
    }

    @Test func refusesCleanupWhileCodexIsRunning() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let archived = root.appendingPathComponent(".codex/archived_sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
        try Data("archived".utf8).write(to: archived.appendingPathComponent("old.jsonl"))

        #expect(throws: ArchiveCleanupError.codexIsRunning) {
            try ArchiveCleanupService.moveToTrash(
                homeURL: root,
                isCodexRunning: { true },
                trash: { _ in
                    Issue.record("Trash must not be called while Codex is running")
                    return nil
                }
            )
        }
        #expect(FileManager.default.fileExists(atPath: archived.appendingPathComponent("old.jsonl").path))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentSpaceCleanupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
