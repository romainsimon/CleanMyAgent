import Foundation
import Testing
@testable import AgentSpace

struct ShellTests {
    @Test func drainsLargeStdoutAndStderrWithoutDeadlock() {
        let result = Shell.run("/usr/bin/python3", ["-c", "import os; os.write(1,b'x'*200000); os.write(2,b'y'*200000)"], timeout: 5)
        #expect(result.status == 0)
        #expect(result.stdout.count == 200_000)
        #expect(result.stderr.count == 200_000)
    }

    @Test func killsAChildThatIgnoresTermination() {
        let start = Date()
        let result = Shell.run("/bin/sh", ["-c", "trap '' TERM; while :; do :; done"], timeout: 0.2)
        #expect(result.status == -2)
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test func closesStandardInput() {
        #expect(Shell.run("/bin/cat", [], timeout: 1).status == 0)
    }
}
