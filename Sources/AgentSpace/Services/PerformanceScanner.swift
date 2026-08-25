import Foundation

enum PerformanceScanner {
    private struct Usage {
        var input: Int64 = 0
        var output: Int64 = 0
        var cached: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0

        static func from(_ dictionary: [String: Any]?) -> Usage {
            guard let dictionary else { return Usage() }
            return Usage(
                input: integer(dictionary["input_tokens"] ?? dictionary["inputTokens"]),
                output: integer(dictionary["output_tokens"] ?? dictionary["outputTokens"]),
                cached: integer(
                    dictionary["cached_input_tokens"]
                    ?? dictionary["cache_read_input_tokens"]
                    ?? dictionary["cachedInputTokens"]
                ),
                reasoning: integer(dictionary["reasoning_output_tokens"] ?? dictionary["reasoningOutputTokens"]),
                total: integer(dictionary["total_tokens"] ?? dictionary["totalTokens"])
            )
        }

        static func difference(_ total: Usage, _ baseline: Usage) -> Usage {
            Usage(
                input: max(0, total.input - baseline.input),
                output: max(0, total.output - baseline.output),
                cached: max(0, total.cached - baseline.cached),
                reasoning: max(0, total.reasoning - baseline.reasoning),
                total: max(0, total.total - baseline.total)
            )
        }

        static func subtract(_ total: Usage, _ last: Usage) -> Usage {
            difference(total, last)
        }
    }

    private struct Accumulator {
        let agent: AgentKind
        var model = "Unknown"
        var input: Int64 = 0
        var output: Int64 = 0
        var cached: Int64 = 0
        var reasoning: Int64 = 0
        var tpsTotal: Double = 0
        var tpsWeight: Double = 0
        var ttftTotal: Double = 0
        var ttftWeight: Double = 0
        var durationTotal: Double = 0
        var durationWeight: Double = 0
        var samples = 0
        var latest: Date?

        mutating func add(
            usage: Usage,
            model: String?,
            tps: Double?,
            ttft: Double?,
            duration: Double?,
            weight: Double = 1,
            date: Date?
        ) {
            input += usage.input
            output += usage.output
            cached += usage.cached
            reasoning += usage.reasoning
            if let model, !model.isEmpty, model != "<synthetic>" { self.model = model }
            if let tps, tps.isFinite, tps > 0 {
                tpsTotal += tps * weight
                tpsWeight += weight
            }
            if let ttft, ttft.isFinite, ttft > 0 {
                ttftTotal += ttft * weight
                ttftWeight += weight
            }
            if let duration, duration.isFinite, duration > 0 {
                durationTotal += duration * weight
                durationWeight += weight
            }
            samples += 1
            if let date, latest == nil || date > latest! { latest = date }
        }

        func metric(coverage: String) -> AgentMetric {
            AgentMetric(
                agent: agent,
                model: model,
                observedTokensPerSecond: tpsWeight > 0 ? tpsTotal / tpsWeight : nil,
                timeToFirstTokenMs: ttftWeight > 0 ? ttftTotal / ttftWeight : nil,
                responseDurationMs: durationWeight > 0 ? durationTotal / durationWeight : nil,
                inputTokens: input,
                outputTokens: output,
                cachedTokens: cached,
                reasoningTokens: reasoning,
                sampleCount: samples,
                coverage: coverage,
                capturedAt: latest
            )
        }
    }

    private struct CodexTurn {
        let usage: Usage
        let model: String
        let tps: Double?
        let ttft: Double?
        let duration: Double?
        let date: Date?
    }

    private struct CodexActive {
        var startedMs: Double
        var model: String
        var baseline: Usage?
        var usage = Usage()
        var recovered = false
    }

    static func scan() -> PerformanceSnapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return PerformanceSnapshot(
            metrics: [scanCodex(home: home), scanClaude(home: home), scanGrok(home: home)],
            capturedAt: Date()
        )
    }

    static func scanCodex(home: String) -> AgentMetric {
        let roots = ["\(home)/.codex/sessions", "\(home)/.codex/archived_sessions"]
        let files = newestFiles(under: roots, named: nil, suffix: ".jsonl", limit: 24)
        guard !files.isEmpty else {
            return .unavailable(.codex, coverage: "No local Codex session metadata found")
        }

        var accumulator = Accumulator(agent: .codex)
        for file in files {
            var model = "Unknown"
            var lastTotals = Usage()
            var totalsKnown = false
            var active: CodexActive?

            for dictionary in jsonLines(at: file, tailBytes: 6 * 1_024 * 1_024) {
                let topType = dictionary["type"] as? String
                let payload = dictionary["payload"] as? [String: Any] ?? [:]
                let eventType = payload["type"] as? String
                let eventMs = timestampMilliseconds(dictionary["timestamp"]) ?? 0

                if topType == "turn_context" {
                    if let nextModel = payload["model"] as? String { model = nextModel }
                    if active != nil { active?.model = model }
                    continue
                }
                guard topType == "event_msg" else { continue }

                if eventType == "task_started" {
                    active = CodexActive(
                        startedMs: timestampMilliseconds(payload["started_at"]) ?? eventMs,
                        model: model,
                        baseline: totalsKnown ? lastTotals : nil
                    )
                    continue
                }

                if eventType == "token_count" {
                    let info = payload["info"] as? [String: Any]
                    let totals = Usage.from(info?["total_token_usage"] as? [String: Any])
                    let last = Usage.from(info?["last_token_usage"] as? [String: Any])
                    if totalsKnown, totals.total < lastTotals.total {
                        totalsKnown = false
                        active?.baseline = nil
                    }
                    if active == nil {
                        active = CodexActive(
                            startedMs: eventMs,
                            model: model,
                            baseline: Usage.subtract(totals, last),
                            usage: last,
                            recovered: true
                        )
                    } else {
                        if active?.baseline == nil { active?.baseline = Usage.subtract(totals, last) }
                        if let baseline = active?.baseline {
                            active?.usage = Usage.difference(totals, baseline)
                        }
                    }
                    lastTotals = totals
                    totalsKnown = true
                    continue
                }

                if eventType == "task_complete" || eventType == "turn_aborted", let current = active {
                    let completedMs = timestampMilliseconds(payload["completed_at"]) ?? eventMs
                    let durationMs = number(payload["duration_ms"]) ?? max(0, completedMs - current.startedMs)
                    let ttftMs = number(payload["time_to_first_token_ms"])
                    let generationMs = max(1, durationMs - (ttftMs ?? 0))
                    let tps = !current.recovered && current.usage.output > 0
                        ? Double(current.usage.output) / (generationMs / 1_000)
                        : nil
                    let turn = CodexTurn(
                        usage: current.usage,
                        model: current.model,
                        tps: tps,
                        ttft: ttftMs,
                        duration: durationMs,
                        date: completedMs > 0 ? Date(timeIntervalSince1970: completedMs / 1_000) : nil
                    )
                    accumulator.add(
                        usage: turn.usage,
                        model: turn.model,
                        tps: turn.tps,
                        ttft: turn.ttft,
                        duration: turn.duration,
                        date: turn.date
                    )
                    active = nil
                }
            }
        }

        guard accumulator.samples > 0 else {
            return .unavailable(.codex, coverage: "Session files found, but no completed turns were covered")
        }
        return accumulator.metric(
            coverage: "Recent local turns. Observed output tok/s excludes TTFT; tool time can lower the value."
        )
    }

    static func scanClaude(home: String) -> AgentMetric {
        let files = newestFiles(
            under: ["\(home)/.claude/projects"],
            named: nil,
            suffix: ".jsonl",
            limit: 24
        )
        guard !files.isEmpty else {
            return .unavailable(.claude, coverage: "No local Claude Code session metadata found")
        }

        var accumulator = Accumulator(agent: .claude)
        for file in files {
            var lastUserMs: Double?
            for dictionary in jsonLines(at: file, tailBytes: 5 * 1_024 * 1_024) {
                let type = dictionary["type"] as? String
                let timestampMs = timestampMilliseconds(dictionary["timestamp"])
                if type == "user" {
                    lastUserMs = timestampMs
                    continue
                }
                guard type == "assistant" else { continue }
                let message = dictionary["message"] as? [String: Any] ?? [:]
                let usage = Usage.from((dictionary["usage"] as? [String: Any]) ?? (message["usage"] as? [String: Any]))
                guard usage.output > 0 else { continue }
                let model = (dictionary["model"] as? String) ?? (message["model"] as? String)
                let explicitDuration = number(dictionary["durationMs"])
                let elapsed = explicitDuration ?? {
                    guard let timestampMs, let lastUserMs else { return nil }
                    return max(1, timestampMs - lastUserMs)
                }()
                let explicitSpeed = number(dictionary["speed"])
                    ?? number((message["usage"] as? [String: Any])?["speed"])
                let tps = explicitSpeed ?? elapsed.map { Double(usage.output) / ($0 / 1_000) }
                accumulator.add(
                    usage: usage,
                    model: model,
                    tps: tps,
                    ttft: nil,
                    duration: elapsed,
                    date: timestampMs.map { Date(timeIntervalSince1970: $0 / 1_000) }
                )
            }
        }

        guard accumulator.samples > 0 else {
            return .unavailable(.claude, coverage: "Session files found, but no assistant usage records were covered")
        }
        return accumulator.metric(
            coverage: "Recent local assistant records. Throughput uses reported speed or output over observed turn time."
        )
    }

    static func scanGrok(home: String) -> AgentMetric {
        let files = newestFiles(
            under: ["\(home)/.grok/sessions"],
            named: "signals.json",
            suffix: nil,
            limit: 40
        )
        guard !files.isEmpty else {
            return .unavailable(.grok, coverage: "No local Grok session signals found")
        }

        var accumulator = Accumulator(agent: .grok)
        for file in files {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
                  let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let contextTokens = integer(dictionary["contextTokensUsed"])
            let beforeCompaction = integer(dictionary["totalTokensBeforeCompaction"])
            let sampleCount = max(1, number(dictionary["itlSampleCount"]) ?? number(dictionary["latencySampleCount"]) ?? 1)
            let interTokenMs = number(dictionary["itlMeanMs"])
            let tps = interTokenMs.flatMap { $0 > 0 ? 1_000 / $0 : nil }
            let modified = (try? FileManager.default.attributesOfItem(atPath: file)[.modificationDate]) as? Date
            accumulator.add(
                usage: Usage(input: contextTokens + beforeCompaction, total: contextTokens + beforeCompaction),
                model: dictionary["primaryModelId"] as? String,
                tps: tps,
                ttft: number(dictionary["avgTimeToFirstTokenMs"]),
                duration: number(dictionary["avgResponseTimeMs"]),
                weight: sampleCount,
                date: modified
            )
        }

        guard accumulator.samples > 0 else {
            return .unavailable(.grok, coverage: "Signal files found, but no readable numeric records were covered")
        }
        return accumulator.metric(
            coverage: "Recent session signals. Tok/s is derived from mean inter-token latency; tokens are context estimates."
        )
    }

    private static func newestFiles(
        under roots: [String],
        named exactName: String?,
        suffix: String?,
        limit: Int
    ) -> [String] {
        let fileManager = FileManager.default
        var candidates: [(String, Date)] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        for root in roots where fileManager.fileExists(atPath: root) {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard exactName == nil || url.lastPathComponent == exactName else { continue }
                guard suffix == nil || url.path.hasSuffix(suffix!) else { continue }
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
                candidates.append((url.path, values.contentModificationDate ?? .distantPast))
            }
        }
        return candidates.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    private static func jsonLines(at path: String, tailBytes: UInt64) -> [[String: Any]] {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return [] }
        defer { try? handle.close() }
        let end = (try? handle.seekToEnd()) ?? 0
        let start = end > tailBytes ? end - tailBytes : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { return [] }
        if start > 0, let newline = data.firstIndex(of: 0x0A) {
            data = data.suffix(from: data.index(after: newline))
        }
        return data.split(separator: 0x0A).compactMap { line in
            try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func integer(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String { return Int64(string) ?? 0 }
        return 0
    }

    private static func timestampMilliseconds(_ value: Any?) -> Double? {
        if let numeric = number(value) {
            return numeric > 10_000_000_000 ? numeric : numeric * 1_000
        }
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date.timeIntervalSince1970 * 1_000 }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: string) else { return nil }
        return date.timeIntervalSince1970 * 1_000
    }
}
