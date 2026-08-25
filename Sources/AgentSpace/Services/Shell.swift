import Foundation

enum Shell {
    struct Result: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) -> Result {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        do {
            try process.run()
            if let timeout {
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.025)
                }
                if process.isRunning {
                    process.terminate()
                    process.waitUntilExit()
                    return Result(status: -2, stdout: "", stderr: "Command timed out")
                }
            } else {
                process.waitUntilExit()
            }
        } catch {
            return Result(status: -1, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Result(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    static func directoryBytes(at path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        let result = run("/usr/bin/du", ["-sk", path])
        guard result.status == 0,
              let first = result.stdout.split(whereSeparator: { $0 == "\t" || $0 == " " }).first,
              let kilobytes = Int64(first) else { return 0 }
        return kilobytes * 1_024
    }

    static func directoryBreakdown(at path: String) -> [String: Int64] {
        guard FileManager.default.fileExists(atPath: path) else { return [:] }
        let result = run("/usr/bin/du", ["-k", "-d", "1", path])
        guard result.status == 0 else { return [:] }

        var breakdown: [String: Int64] = [:]
        for line in result.stdout.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let kilobytes = Int64(parts[0]) else { continue }
            breakdown[String(parts[1])] = kilobytes * 1_024
        }
        return breakdown
    }
}
