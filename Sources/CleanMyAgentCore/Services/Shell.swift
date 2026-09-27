import Darwin
import Foundation

enum Shell {
    struct Result: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    // Drain both pipes while the child runs. Bound command time, output, and inherited pipes.
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
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = errors
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        do { try process.run() }
        catch { return Result(status: -1, stdout: "", stderr: error.localizedDescription) }

        try? output.fileHandleForWriting.close()
        try? errors.fileHandleForWriting.close()
        let stdoutFD = output.fileHandleForReading.fileDescriptor
        let stderrFD = errors.fileHandleForReading.fileDescriptor
        for fd in [stdoutFD, stderrFD] { _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) }
        defer {
            try? output.fileHandleForReading.close()
            try? errors.fileHandleForReading.close()
        }
        var stdout = Data(), stderr = Data()
        var truncated = false
        let limit = 8 * 1_024 * 1_024
        func drain(_ fd: Int32, into data: inout Data) {
            var buffer = [UInt8](repeating: 0, count: 16_384)
            // A noisy child must not starve the other pipe or the deadline check.
            for _ in 0..<64 {
                let count = read(fd, &buffer, buffer.count)
                guard count > 0 else { return }
                if data.count + count <= limit { data.append(contentsOf: buffer.prefix(count)) }
                else { truncated = true }
            }
        }
        let deadline = ProcessInfo.processInfo.systemUptime + max(0.01, timeout ?? 30)
        var timedOut = false
        while process.isRunning {
            drain(stdoutFD, into: &stdout)
            drain(stderrFD, into: &stderr)
            if ProcessInfo.processInfo.systemUptime >= deadline {
                timedOut = true
                process.terminate()
                let grace = ProcessInfo.processInfo.systemUptime + 0.25
                while process.isRunning && ProcessInfo.processInfo.systemUptime < grace {
                    drain(stdoutFD, into: &stdout)
                    drain(stderrFD, into: &stderr)
                    usleep(10_000)
                }
                if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
                let killDeadline = ProcessInfo.processInfo.systemUptime + 1
                while process.isRunning && ProcessInfo.processInfo.systemUptime < killDeadline { usleep(10_000) }
                break
            }
            usleep(10_000)
        }
        drain(stdoutFD, into: &stdout)
        drain(stderrFD, into: &stderr)
        return Result(
            status: timedOut ? -2 : (truncated ? -3 : process.terminationStatus),
            stdout: String(data: stdout, encoding: .utf8) ?? "",
            stderr: timedOut ? "Command timed out" : (truncated ? "Command output exceeded the safety limit" : String(data: stderr, encoding: .utf8) ?? "")
        )
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
