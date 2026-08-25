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

    private func temporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
