import Foundation
import Testing
@testable import AgentSpace

struct PerformanceScannerTests {
    @Test func parsesCodexObservedThroughputWithoutContent() throws {
        let home = try temporaryHome()
        let directory = home.appendingPathComponent(".codex/sessions/2026/08/25", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("session.jsonl")
        let lines = [
            #"{"timestamp":"2026-08-25T10:00:00.000Z","type":"turn_context","payload":{"model":"gpt-test"}}"#,
            #"{"timestamp":"2026-08-25T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"one"}}"#,
            #"{"timestamp":"2026-08-25T10:00:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":50,"total_tokens":150},"last_token_usage":{"input_tokens":100,"output_tokens":50,"total_tokens":150}}}}"#,
            #"{"timestamp":"2026-08-25T10:00:02.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"one","duration_ms":2000,"time_to_first_token_ms":1000}}"#
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)

        let metric = PerformanceScanner.scanCodex(home: home.path)
        #expect(metric.model == "gpt-test")
        #expect(metric.outputTokens == 50)
        #expect(metric.observedTokensPerSecond == 50)
    }

    @Test func derivesGrokSpeedFromInterTokenLatency() throws {
        let home = try temporaryHome()
        let directory = home.appendingPathComponent(".grok/sessions/project/session", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "primaryModelId": "grok-test",
            "contextTokensUsed": 1_000,
            "totalTokensBeforeCompaction": 2_000,
            "itlMeanMs": 20,
            "itlSampleCount": 10,
            "avgTimeToFirstTokenMs": 400,
            "avgResponseTimeMs": 2_000
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: directory.appendingPathComponent("signals.json"))

        let metric = PerformanceScanner.scanGrok(home: home.path)
        #expect(metric.model == "grok-test")
        #expect(metric.inputTokens == 3_000)
        #expect(metric.observedTokensPerSecond == 50)
        #expect(metric.timeToFirstTokenMs == 400)
    }

    @Test func readsOpenCodeSessionTotalsWithoutInventingThroughput() throws {
        let home = try temporaryHome()
        let directory = home.appendingPathComponent(".local/share/opencode", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("opencode.db")
        let result = Shell.run(
            "/usr/bin/sqlite3",
            [
                database.path,
                """
                CREATE TABLE session (
                    model TEXT, time_updated INTEGER, tokens_input INTEGER, tokens_output INTEGER,
                    tokens_reasoning INTEGER, tokens_cache_read INTEGER, tokens_cache_write INTEGER
                );
                INSERT INTO session VALUES ('{"id":"open-test"}', 1787659200000, 100, 40, 8, 20, 5);
                """
            ],
            timeout: 3
        )
        #expect(result.status == 0)

        let metric = PerformanceScanner.scanOpenCode(home: home.path)
        #expect(metric.model == "open-test")
        #expect(metric.inputTokens == 125)
        #expect(metric.outputTokens == 40)
        #expect(metric.observedTokensPerSecond == nil)
    }

    private func temporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
