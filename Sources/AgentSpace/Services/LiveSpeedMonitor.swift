import Foundation

actor LiveSpeedMonitor {
    private struct Usage {
        var output: Int64 = 0
        var total: Int64 = 0

        static func from(_ dictionary: [String: Any]?) -> Usage {
            guard let dictionary else { return Usage() }
            return Usage(
                output: integer(dictionary["output_tokens"] ?? dictionary["outputTokens"]),
                total: integer(dictionary["total_tokens"] ?? dictionary["totalTokens"])
            )
        }

        static func subtract(_ total: Usage, _ baseline: Usage) -> Usage {
            Usage(
                output: max(0, total.output - baseline.output),
                total: max(0, total.total - baseline.total)
            )
        }

        private static func integer(_ value: Any?) -> Int64 {
            if let number = value as? NSNumber { return number.int64Value }
            if let string = value as? String { return Int64(string) ?? 0 }
            return 0
        }
    }

    private struct ActiveTurn {
        var model: String
        var startedMs: Double
        var baseline: Usage?
        var usage = Usage()
    }

    private var candidates: [String] = []
    private var lastDiscovery = Date.distantPast

    func sample() -> LiveSpeedSnapshot {
        let now = Date()
        if candidates.isEmpty || now.timeIntervalSince(lastDiscovery) >= 20 {
            candidates = discoverRecentSessionFiles(now: now)
            lastDiscovery = now
        }

        let active = candidates
            .compactMap { parseActiveTurn(at: $0, now: now) }
            .min { $0.elapsedMs < $1.elapsedMs }

        return active ?? LiveSpeedSnapshot(
            active: false,
            agent: .codex,
            model: nil,
            observedTokensPerSecond: 0,
            outputTokens: 0,
            totalTokens: 0,
            elapsedMs: 0,
            sampledAt: now
        )
    }

    private func discoverRecentSessionFiles(now: Date) -> [String] {
        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions", isDirectory: true)
        let calendar = Calendar(identifier: .gregorian)
        var files: [(path: String, modified: Date)] = []

        for dayOffset in 0...2 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { continue }
            let directory = root
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "jsonl" {
                guard let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true else { continue }
                files.append((entry.path, values.contentModificationDate ?? .distantPast))
            }
        }

        return files
            .sorted { $0.modified > $1.modified }
            .prefix(4)
            .map(\.path)
    }

    private func parseActiveTurn(at path: String, now: Date) -> LiveSpeedSnapshot? {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let modified = attributes[.modificationDate] as? Date,
              now.timeIntervalSince(modified) < 10 * 60 else { return nil }

        var model = "Unknown"
        var lastTotals = Usage()
        var totalsKnown = false
        var active: ActiveTurn?

        for dictionary in jsonLines(at: path, tailBytes: 1 * 1_024 * 1_024) {
            let topType = dictionary["type"] as? String
            let payload = dictionary["payload"] as? [String: Any] ?? [:]
            let eventType = payload["type"] as? String
            let eventMs = timestampMilliseconds(dictionary["timestamp"]) ?? now.timeIntervalSince1970 * 1_000

            if topType == "turn_context" {
                if let nextModel = payload["model"] as? String { model = nextModel }
                if active != nil { active?.model = model }
                continue
            }
            guard topType == "event_msg" else { continue }

            if eventType == "task_started" {
                active = ActiveTurn(
                    model: model,
                    startedMs: timestampMilliseconds(payload["started_at"]) ?? eventMs,
                    baseline: totalsKnown ? lastTotals : nil
                )
                continue
            }

            if eventType == "token_count" {
                let info = payload["info"] as? [String: Any]
                let totals = Usage.from(info?["total_token_usage"] as? [String: Any])
                let last = Usage.from(info?["last_token_usage"] as? [String: Any])

                if active == nil {
                    active = ActiveTurn(
                        model: model,
                        startedMs: eventMs,
                        baseline: Usage.subtract(totals, last),
                        usage: last
                    )
                } else {
                    if active?.baseline == nil { active?.baseline = Usage.subtract(totals, last) }
                    if let baseline = active?.baseline {
                        active?.usage = Usage.subtract(totals, baseline)
                    }
                }
                lastTotals = totals
                totalsKnown = true
                continue
            }

            if eventType == "task_complete" || eventType == "turn_aborted" {
                active = nil
            }
        }

        guard let active else { return nil }
        let nowMs = now.timeIntervalSince1970 * 1_000
        let elapsedMs = max(1, nowMs - active.startedMs)
        guard elapsedMs < 2 * 60 * 60 * 1_000 else { return nil }
        return LiveSpeedSnapshot(
            active: true,
            agent: .codex,
            model: active.model,
            observedTokensPerSecond: Double(active.usage.output) / (elapsedMs / 1_000),
            outputTokens: active.usage.output,
            totalTokens: active.usage.total,
            elapsedMs: elapsedMs,
            sampledAt: now
        )
    }

    private func jsonLines(at path: String, tailBytes: UInt64) -> [[String: Any]] {
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

    private func timestampMilliseconds(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            let numeric = number.doubleValue
            return numeric > 10_000_000_000 ? numeric : numeric * 1_000
        }
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date.timeIntervalSince1970 * 1_000 }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string).map { $0.timeIntervalSince1970 * 1_000 }
    }
}
