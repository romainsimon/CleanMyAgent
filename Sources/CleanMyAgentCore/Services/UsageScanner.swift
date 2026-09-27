import Foundation

enum UsageScanner {
    private struct Usage {
        var input: Int64 = 0
        var output: Int64 = 0
        var cacheRead: Int64 = 0
        var cacheWrite: Int64 = 0
        var reasoning: Int64 = 0
        var reportedCostUSD: Double = 0

        var hasTokens: Bool {
            input > 0 || output > 0 || cacheRead > 0 || cacheWrite > 0 || reasoning > 0
        }

        static func codex(_ dictionary: [String: Any]?) -> Usage {
            guard let dictionary else { return Usage() }
            return Usage(
                input: integer(dictionary["input_tokens"] ?? dictionary["inputTokens"]),
                output: integer(dictionary["output_tokens"] ?? dictionary["outputTokens"]),
                cacheRead: integer(dictionary["cached_input_tokens"] ?? dictionary["cachedInputTokens"]),
                cacheWrite: integer(dictionary["cache_write_input_tokens"] ?? dictionary["cacheWriteInputTokens"]),
                reasoning: integer(dictionary["reasoning_output_tokens"] ?? dictionary["reasoningOutputTokens"])
            )
        }

        static func claude(_ dictionary: [String: Any]?) -> Usage {
            guard let dictionary else { return Usage() }
            let directInput = integer(dictionary["input_tokens"] ?? dictionary["inputTokens"])
            let cacheRead = integer(dictionary["cache_read_input_tokens"] ?? dictionary["cacheReadInputTokens"])
            let cacheWrite = integer(dictionary["cache_creation_input_tokens"] ?? dictionary["cacheCreationInputTokens"])
            return Usage(
                input: directInput + cacheRead + cacheWrite,
                output: integer(dictionary["output_tokens"] ?? dictionary["outputTokens"]),
                cacheRead: cacheRead,
                cacheWrite: cacheWrite
            )
        }

        static func difference(_ total: Usage, _ baseline: Usage) -> Usage {
            Usage(
                input: max(0, total.input - baseline.input),
                output: max(0, total.output - baseline.output),
                cacheRead: max(0, total.cacheRead - baseline.cacheRead),
                cacheWrite: max(0, total.cacheWrite - baseline.cacheWrite),
                reasoning: max(0, total.reasoning - baseline.reasoning)
            )
        }
    }

    private struct Event {
        let date: Date
        let agent: AgentKind
        let model: String
        let usage: Usage
        let session: String
    }

    private struct Candidate {
        let path: String
        let modified: Date
    }

    private struct ScanResult {
        let events: [Event]
        let coverage: UsageCoverage
    }

    private struct CodexActive {
        var model: String
        var baseline: Usage?
        var usage = Usage()
        var lastDate: Date?
    }

    private struct BucketKey: Hashable {
        let day: Date
        let agent: AgentKind
    }

    private struct ModelKey: Hashable {
        let agent: AgentKind
        let model: String
    }

    private struct Aggregate {
        var input: Int64 = 0
        var output: Int64 = 0
        var cacheRead: Int64 = 0
        var cacheWrite: Int64 = 0
        var reasoning: Int64 = 0
        var reportedCostUSD: Double = 0
        var sessions: Set<String> = []

        mutating func add(_ event: Event) {
            input += event.usage.input
            output += event.usage.output
            cacheRead += event.usage.cacheRead
            cacheWrite += event.usage.cacheWrite
            reasoning += event.usage.reasoning
            reportedCostUSD += event.usage.reportedCostUSD
            sessions.insert(event.session)
        }
    }

    static func scan(
        range: UsageRange,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        now: Date = Date()
    ) -> UsageSnapshot {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today) ?? today
        let fileLimit = switch range {
        case .sevenDays: 120
        case .thirtyDays: 300
        case .ninetyDays: 600
        }

        let results = [
            scanCodex(home: home, start: start, now: now, limit: fileLimit),
            scanClaude(home: home, start: start, limit: fileLimit),
            scanGrok(home: home, start: start, limit: fileLimit),
            unavailable(.cursor, note: "Cursor does not expose a stable local token ledger."),
            scanHermes(home: home, start: start, limit: fileLimit),
            scanOpenCode(home: home, start: start, limit: fileLimit),
            scanOri(home: home, start: start),
            unavailable(.kiloCode, note: "Kilo Code token telemetry is not exposed through a stable local format.")
        ]
        let events = results.flatMap(\.events).filter { $0.date >= start && $0.date <= now }
        var daily: [BucketKey: Aggregate] = [:]
        var models: [ModelKey: Aggregate] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.date)
            daily[BucketKey(day: day, agent: event.agent), default: Aggregate()].add(event)
            models[ModelKey(agent: event.agent, model: event.model), default: Aggregate()].add(event)
        }

        var buckets: [UsageBucket] = []
        for (key, aggregate) in daily {
            buckets.append(UsageBucket(
                date: key.day,
                agent: key.agent,
                inputTokens: aggregate.input,
                outputTokens: aggregate.output,
                cacheReadTokens: aggregate.cacheRead,
                cacheWriteTokens: aggregate.cacheWrite,
                reasoningTokens: aggregate.reasoning,
                reportedCostUSD: aggregate.reportedCostUSD,
                sessions: aggregate.sessions.count
            ))
        }
        buckets.sort { lhs, rhs in
            lhs.date == rhs.date ? lhs.agent.rawValue < rhs.agent.rawValue : lhs.date < rhs.date
        }

        var modelUsage: [ModelUsage] = []
        for (key, aggregate) in models {
            modelUsage.append(ModelUsage(
                agent: key.agent,
                model: key.model,
                inputTokens: aggregate.input,
                outputTokens: aggregate.output,
                cacheReadTokens: aggregate.cacheRead,
                cacheWriteTokens: aggregate.cacheWrite,
                reasoningTokens: aggregate.reasoning,
                reportedCostUSD: aggregate.reportedCostUSD,
                sessions: aggregate.sessions.count
            ))
        }
        modelUsage.sort { $0.totalTokens > $1.totalTokens }

        return UsageSnapshot(
            range: range,
            buckets: buckets,
            models: modelUsage,
            coverage: results.map(\.coverage),
            sessionCount: Set(events.map(\.session)).count,
            capturedAt: now
        )
    }

    private static func scanCodex(home: String, start: Date, now: Date, limit: Int) -> ScanResult {
        let calendar = Calendar.autoupdatingCurrent
        let root = URL(fileURLWithPath: home).appendingPathComponent(".codex/sessions", isDirectory: true)
        let dayCount = max(1, calendar.dateComponents([.day], from: start, to: now).day ?? 0) + 1
        var candidates: [Candidate] = []

        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { continue }
            let directory = root
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
            candidates += files(in: directory, suffix: ".jsonl")
        }

        let selected = newest(candidates, limit: limit)
        var events: [Event] = []
        var truncated = 0
        for candidate in selected {
            let read = jsonLines(at: candidate.path, tailBytes: 1 * 1_024 * 1_024)
            if read.truncated { truncated += 1 }
            events += codexEvents(from: read.lines, session: candidate.path, fallbackDate: candidate.modified)
        }
        return ScanResult(
            events: events,
            coverage: UsageCoverage(
                agent: .codex,
                filesDiscovered: candidates.count,
                filesScanned: selected.count,
                truncatedFiles: truncated,
                status: .measured,
                note: "Active Codex session history; archived sessions are not scanned."
            )
        )
    }

    private static func codexEvents(
        from lines: [[String: Any]],
        session: String,
        fallbackDate: Date
    ) -> [Event] {
        var events: [Event] = []
        var model = "Unknown"
        var lastTotals = Usage()
        var totalsKnown = false
        var active: CodexActive?

        func event(from current: CodexActive, date: Date) -> Event? {
            guard current.usage.hasTokens else { return nil }
            return Event(date: date, agent: .codex, model: current.model, usage: current.usage, session: session)
        }

        for dictionary in lines {
            let topType = dictionary["type"] as? String
            let payload = dictionary["payload"] as? [String: Any] ?? [:]
            let eventType = payload["type"] as? String
            let timestamp = date(dictionary["timestamp"]) ?? fallbackDate

            if topType == "turn_context" {
                if let nextModel = payload["model"] as? String, !nextModel.isEmpty { model = nextModel }
                if active != nil { active?.model = model }
                continue
            }
            guard topType == "event_msg" else { continue }

            if eventType == "task_started" {
                active = CodexActive(model: model, baseline: totalsKnown ? lastTotals : nil, lastDate: timestamp)
                continue
            }

            if eventType == "token_count" {
                let info = payload["info"] as? [String: Any]
                let totals = Usage.codex(info?["total_token_usage"] as? [String: Any])
                let last = Usage.codex(info?["last_token_usage"] as? [String: Any])
                if totalsKnown, totals.input + totals.output < lastTotals.input + lastTotals.output {
                    totalsKnown = false
                    active?.baseline = nil
                }
                if active == nil {
                    active = CodexActive(
                        model: model,
                        baseline: Usage.difference(totals, last),
                        usage: last,
                        lastDate: timestamp
                    )
                } else {
                    if active?.baseline == nil { active?.baseline = Usage.difference(totals, last) }
                    if let baseline = active?.baseline { active?.usage = Usage.difference(totals, baseline) }
                    active?.lastDate = timestamp
                }
                lastTotals = totals
                totalsKnown = true
                continue
            }

            if eventType == "task_complete" || eventType == "turn_aborted", let current = active {
                if let completed = event(from: current, date: timestamp) { events.append(completed) }
                active = nil
            }
        }

        if let active, let partial = event(from: active, date: active.lastDate ?? fallbackDate) {
            events.append(partial)
        }
        return events
    }

    private static func scanClaude(home: String, start: Date, limit: Int) -> ScanResult {
        let root = URL(fileURLWithPath: home).appendingPathComponent(".claude/projects", isDirectory: true)
        let candidates = recursiveFiles(under: root, suffix: ".jsonl", modifiedAfter: start)
        let selected = newest(candidates, limit: limit)
        var events: [Event] = []
        var truncated = 0

        for candidate in selected {
            let read = jsonLines(at: candidate.path, tailBytes: 1 * 1_024 * 1_024)
            if read.truncated { truncated += 1 }
            for dictionary in read.lines where dictionary["type"] as? String == "assistant" {
                let message = dictionary["message"] as? [String: Any] ?? [:]
                let usage = Usage.claude(
                    (dictionary["usage"] as? [String: Any]) ?? (message["usage"] as? [String: Any])
                )
                guard usage.hasTokens else { continue }
                events.append(Event(
                    date: date(dictionary["timestamp"]) ?? candidate.modified,
                    agent: .claude,
                    model: (dictionary["model"] as? String) ?? (message["model"] as? String) ?? "Unknown",
                    usage: usage,
                    session: candidate.path
                ))
            }
        }
        return ScanResult(
            events: events,
            coverage: UsageCoverage(
                agent: .claude,
                filesDiscovered: candidates.count,
                filesScanned: selected.count,
                truncatedFiles: truncated,
                status: .measured,
                note: "Recent Claude Code project sessions selected by modification date."
            )
        )
    }

    private static func scanGrok(home: String, start: Date, limit: Int) -> ScanResult {
        let root = URL(fileURLWithPath: home).appendingPathComponent(".grok/sessions", isDirectory: true)
        let candidates = recursiveFiles(under: root, exactName: "signals.json", modifiedAfter: start)
        let selected = newest(candidates, limit: limit)
        var events: [Event] = []

        for candidate in selected {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: candidate.path)),
                  let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let tokens = integer(dictionary["contextTokensUsed"]) + integer(dictionary["totalTokensBeforeCompaction"])
            guard tokens > 0 else { continue }
            events.append(Event(
                date: candidate.modified,
                agent: .grok,
                model: dictionary["primaryModelId"] as? String ?? "Unknown",
                usage: Usage(input: tokens),
                session: candidate.path
            ))
        }
        return ScanResult(
            events: events,
            coverage: UsageCoverage(
                agent: .grok,
                filesDiscovered: candidates.count,
                filesScanned: selected.count,
                truncatedFiles: 0,
                status: .estimated,
                note: "Grok exposes context estimates per session, not complete input/output billing usage."
            )
        )
    }

    private static func scanOpenCode(home: String, start: Date, limit: Int) -> ScanResult {
        let database = "\(home)/.local/share/opencode/opencode.db"
        let startMilliseconds = Int64(start.timeIntervalSince1970 * 1_000)
        let sql = """
            SELECT id, model, time_updated,
                   COALESCE(tokens_input, 0) AS input_tokens,
                   COALESCE(tokens_output, 0) AS output_tokens,
                   COALESCE(tokens_reasoning, 0) AS reasoning_tokens,
                   COALESCE(tokens_cache_read, 0) AS cache_read_tokens,
                   COALESCE(tokens_cache_write, 0) AS cache_write_tokens,
                   COALESCE(cost, 0) AS reported_cost
            FROM session
            WHERE time_updated >= \(startMilliseconds)
              AND COALESCE(tokens_input, 0) + COALESCE(tokens_output, 0) > 0
            ORDER BY time_updated DESC
            LIMIT \(limit);
            """
        guard let rows = SQLiteMetadata.query(database: database, sql: sql) else {
            return unavailable(.openCode, note: "No readable OpenCode session database was found.")
        }
        let events = rows.compactMap { row -> Event? in
            guard let timestamp = date(row["time_updated"]) else { return nil }
            let cacheRead = integer(row["cache_read_tokens"])
            let cacheWrite = integer(row["cache_write_tokens"])
            let directInput = integer(row["input_tokens"])
            let usage = Usage(
                input: directInput + cacheRead + cacheWrite,
                output: integer(row["output_tokens"]),
                cacheRead: cacheRead,
                cacheWrite: cacheWrite,
                reasoning: integer(row["reasoning_tokens"]),
                reportedCostUSD: decimal(row["reported_cost"])
            )
            guard usage.hasTokens else { return nil }
            return Event(
                date: timestamp,
                agent: .openCode,
                model: modelName(row["model"]),
                usage: usage,
                session: (row["id"] as? String) ?? "opencode-\(timestamp.timeIntervalSince1970)"
            )
        }
        return ScanResult(
            events: events,
            coverage: UsageCoverage(
                agent: .openCode,
                filesDiscovered: 1,
                filesScanned: 1,
                truncatedFiles: 0,
                status: .measured,
                note: "Session totals and provider-reported costs from OpenCode's local database."
            )
        )
    }

    private static func scanHermes(home: String, start: Date, limit: Int) -> ScanResult {
        let database = "\(home)/.hermes/state.db"
        let startSeconds = start.timeIntervalSince1970
        let sql = """
            SELECT id, model, COALESCE(ended_at, started_at) AS occurred_at,
                   COALESCE(input_tokens, 0) AS input_tokens,
                   COALESCE(output_tokens, 0) AS output_tokens,
                   COALESCE(reasoning_tokens, 0) AS reasoning_tokens,
                   COALESCE(cache_read_tokens, 0) AS cache_read_tokens,
                   COALESCE(cache_write_tokens, 0) AS cache_write_tokens,
                   COALESCE(actual_cost_usd, estimated_cost_usd, 0) AS reported_cost
            FROM sessions
            WHERE started_at >= \(startSeconds)
              AND COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0) > 0
            ORDER BY started_at DESC
            LIMIT \(limit);
            """
        guard let rows = SQLiteMetadata.query(database: database, sql: sql) else {
            return unavailable(.hermes, note: "No readable Hermes session database was found.")
        }
        let events = rows.compactMap { row -> Event? in
            guard let timestamp = date(row["occurred_at"]) else { return nil }
            let cacheRead = integer(row["cache_read_tokens"])
            let cacheWrite = integer(row["cache_write_tokens"])
            let usage = Usage(
                input: integer(row["input_tokens"]) + cacheRead + cacheWrite,
                output: integer(row["output_tokens"]),
                cacheRead: cacheRead,
                cacheWrite: cacheWrite,
                reasoning: integer(row["reasoning_tokens"]),
                reportedCostUSD: decimal(row["reported_cost"])
            )
            guard usage.hasTokens else { return nil }
            return Event(
                date: timestamp,
                agent: .hermes,
                model: modelName(row["model"]),
                usage: usage,
                session: (row["id"] as? String) ?? "hermes-\(timestamp.timeIntervalSince1970)"
            )
        }
        return ScanResult(
            events: events,
            coverage: UsageCoverage(
                agent: .hermes,
                filesDiscovered: 1,
                filesScanned: 1,
                truncatedFiles: 0,
                status: .measured,
                note: "Session totals and recorded costs from Hermes' local database."
            )
        )
    }

    private static func scanOri(home: String, start: Date) -> ScanResult {
        let root = URL(fileURLWithPath: home).appendingPathComponent(".ori/logs/sessions", isDirectory: true)
        let metadata = recursiveFiles(under: root, exactName: "metadata.json", modifiedAfter: start)
        return ScanResult(
            events: [],
            coverage: UsageCoverage(
                agent: .ori,
                filesDiscovered: metadata.count,
                filesScanned: metadata.count,
                truncatedFiles: 0,
                status: .duplicate,
                note: "Ori launcher history is detected, but its tokens are not counted again after the underlying agent."
            )
        )
    }

    private static func unavailable(_ agent: AgentKind, note: String) -> ScanResult {
        ScanResult(
            events: [],
            coverage: UsageCoverage(
                agent: agent,
                filesDiscovered: 0,
                filesScanned: 0,
                truncatedFiles: 0,
                status: .unavailable,
                note: note
            )
        )
    }

    private static func files(in directory: URL, suffix: String) -> [Candidate] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.compactMap { url in
            guard url.path.hasSuffix(suffix),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { return nil }
            return Candidate(path: url.path, modified: values.contentModificationDate ?? .distantPast)
        }
    }

    private static func recursiveFiles(
        under root: URL,
        suffix: String? = nil,
        exactName: String? = nil,
        modifiedAfter: Date
    ) -> [Candidate] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else { return [] }
        var candidates: [Candidate] = []
        for case let url as URL in enumerator {
            guard exactName == nil || url.lastPathComponent == exactName else { continue }
            guard suffix == nil || url.path.hasSuffix(suffix!) else { continue }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= modifiedAfter else { continue }
            candidates.append(Candidate(path: url.path, modified: modified))
        }
        return candidates
    }

    private static func newest(_ candidates: [Candidate], limit: Int) -> [Candidate] {
        Array(candidates.sorted { $0.modified > $1.modified }.prefix(limit))
    }

    private static func jsonLines(
        at path: String,
        tailBytes: UInt64
    ) -> (lines: [[String: Any]], truncated: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return ([], false) }
        defer { try? handle.close() }
        let end = (try? handle.seekToEnd()) ?? 0
        let start = end > tailBytes ? end - tailBytes : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { return ([], start > 0) }
        if start > 0, let newline = data.firstIndex(of: 0x0A) {
            data = data.suffix(from: data.index(after: newline))
        }
        let lines = data.split(separator: 0x0A).compactMap { line in
            try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
        }
        return (lines, start > 0)
    }

    private static func integer(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String { return Int64(string) ?? 0 }
        return 0
    }

    private static func decimal(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) ?? 0 }
        return 0
    }

    private static func modelName(_ value: Any?) -> String {
        guard let string = value as? String, !string.isEmpty else { return "Unknown" }
        guard let data = string.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return string }
        return (dictionary["id"] as? String) ?? (dictionary["model"] as? String) ?? string
    }

    private static func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let numeric = number.doubleValue
            return Date(timeIntervalSince1970: numeric > 10_000_000_000 ? numeric / 1_000 : numeric)
        }
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: string) { return parsed }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
