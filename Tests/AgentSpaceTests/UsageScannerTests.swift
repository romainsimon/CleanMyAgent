import Foundation
import Testing
@testable import AgentSpace

struct UsageScannerTests {
    @Test func aggregatesCodexAndClaudeUsageWithoutDoubleCountingCache() throws {
        let home = try temporaryHome()
        let now = try #require(ISO8601DateFormatter().date(from: "2026-08-25T12:00:00Z"))

        let codexDirectory = home.appendingPathComponent(".codex/sessions/2026/08/25", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let codexFile = codexDirectory.appendingPathComponent("codex.jsonl")
        let codexLines = [
            #"{"timestamp":"2026-08-25T10:00:00.000Z","type":"turn_context","payload":{"model":"gpt-test"}}"#,
            #"{"timestamp":"2026-08-25T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"timestamp":"2026-08-25T10:00:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":50,"cached_input_tokens":20,"cache_write_input_tokens":5,"reasoning_output_tokens":10},"last_token_usage":{"input_tokens":100,"output_tokens":50,"cached_input_tokens":20,"cache_write_input_tokens":5,"reasoning_output_tokens":10}}}}"#,
            #"{"timestamp":"2026-08-25T10:00:02.000Z","type":"event_msg","payload":{"type":"task_complete"}}"#
        ]
        try (codexLines.joined(separator: "\n") + "\n").write(to: codexFile, atomically: true, encoding: .utf8)

        let claudeDirectory = home.appendingPathComponent(".claude/projects/test", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        let claudeFile = claudeDirectory.appendingPathComponent("claude.jsonl")
        let claudeLine = #"{"timestamp":"2026-08-25T11:00:00.000Z","type":"assistant","message":{"model":"claude-test","usage":{"input_tokens":10,"output_tokens":40,"cache_read_input_tokens":20,"cache_creation_input_tokens":30}}}"#
        try (claudeLine + "\n").write(to: claudeFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: claudeFile.path)

        let snapshot = UsageScanner.scan(range: .sevenDays, home: home.path, now: now)

        #expect(snapshot.inputTokens == 160)
        #expect(snapshot.outputTokens == 90)
        #expect(snapshot.cacheReadTokens == 40)
        #expect(snapshot.cacheWriteTokens == 35)
        #expect(snapshot.reasoningTokens == 10)
        #expect(snapshot.totalTokens == 250)
        #expect(snapshot.models.contains { $0.model == "gpt-test" && $0.totalTokens == 150 })
        #expect(snapshot.models.contains { $0.model == "claude-test" && $0.totalTokens == 100 })
    }

    @Test func aggregatesOpenCodeAndHermesReportedMetadata() throws {
        let home = try temporaryHome()
        let now = try #require(ISO8601DateFormatter().date(from: "2026-08-25T12:00:00Z"))
        let timestampMilliseconds = Int64(now.addingTimeInterval(-60).timeIntervalSince1970 * 1_000)
        let timestampSeconds = now.addingTimeInterval(-120).timeIntervalSince1970

        let openCodeDirectory = home.appendingPathComponent(".local/share/opencode", isDirectory: true)
        try FileManager.default.createDirectory(at: openCodeDirectory, withIntermediateDirectories: true)
        let openCodeDatabase = openCodeDirectory.appendingPathComponent("opencode.db")
        try runSQLite(
            database: openCodeDatabase,
            sql: """
                CREATE TABLE session (
                    id TEXT, model TEXT, time_updated INTEGER, tokens_input INTEGER,
                    tokens_output INTEGER, tokens_reasoning INTEGER, tokens_cache_read INTEGER,
                    tokens_cache_write INTEGER, cost REAL
                );
                INSERT INTO session VALUES (
                    'open-one', '{"id":"open-model"}', \(timestampMilliseconds),
                    100, 50, 10, 20, 5, 0.42
                );
                """
        )

        let hermesDirectory = home.appendingPathComponent(".hermes", isDirectory: true)
        try FileManager.default.createDirectory(at: hermesDirectory, withIntermediateDirectories: true)
        let hermesDatabase = hermesDirectory.appendingPathComponent("state.db")
        try runSQLite(
            database: hermesDatabase,
            sql: """
                CREATE TABLE sessions (
                    id TEXT, model TEXT, started_at REAL, ended_at REAL,
                    input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
                    cache_read_tokens INTEGER, cache_write_tokens INTEGER,
                    actual_cost_usd REAL, estimated_cost_usd REAL
                );
                INSERT INTO sessions VALUES (
                    'hermes-one', 'hermes-model', \(timestampSeconds), \(timestampSeconds + 30),
                    200, 60, 15, 30, 10, 0.80, 0.75
                );
                """
        )

        let snapshot = UsageScanner.scan(range: .sevenDays, home: home.path, now: now)

        #expect(snapshot.totalTokens == 475)
        #expect(snapshot.cacheReadTokens == 50)
        #expect(snapshot.cacheWriteTokens == 15)
        #expect(snapshot.reasoningTokens == 25)
        #expect(abs(snapshot.reportedCostUSD - 1.22) < 0.0001)
        #expect(snapshot.models.contains { $0.agent == .openCode && $0.model == "open-model" && $0.totalTokens == 175 })
        #expect(snapshot.models.contains { $0.agent == .hermes && $0.model == "hermes-model" && $0.totalTokens == 300 })
        #expect(snapshot.coverage.contains { $0.agent == .ori && $0.status == .duplicate })
        #expect(snapshot.coverage.contains { $0.agent == .cursor && $0.status == .unavailable })
    }

    private func runSQLite(database: URL, sql: String) throws {
        let result = Shell.run("/usr/bin/sqlite3", [database.path, sql], timeout: 3)
        guard result.status == 0 else {
            throw SQLiteFixtureError.failed(result.stderr)
        }
    }

    private func temporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum SQLiteFixtureError: Error {
    case failed(String)
}
