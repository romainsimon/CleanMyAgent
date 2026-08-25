import Testing
@testable import AgentSpace

struct ProcessScannerTests {
    @Test func classifiesInstalledAgentProcessesWithoutClaimingSharedExtensionHosts() {
        #expect(ProcessScanner.agent(for: "/Applications/Cursor.app/Contents/MacOS/Cursor --type=renderer") == .cursor)
        #expect(ProcessScanner.agent(for: "/Users/test/.local/bin/hermes chat") == .hermes)
        #expect(ProcessScanner.agent(for: "/Applications/OpenCode.app/Contents/MacOS/OpenCode") == .openCode)
        #expect(ProcessScanner.agent(for: "/Users/test/.local/bin/ori codex") == .ori)
        #expect(ProcessScanner.agent(for: "/Users/test/.grok/bin/grok") == .grok)
        #expect(ProcessScanner.agent(for: "/Users/test/dev/CleanMyAgent/dist/CleanMyAgent.app/Contents/MacOS/CleanMyAgent") == nil)
        #expect(ProcessScanner.agent(for: "/Applications/Cursor.app/Contents/Frameworks/extensionHost kilocode.kilo-code") == .cursor)
        #expect(ProcessScanner.agent(for: "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Versions/A/Helpers/Codex (Renderer) --type=renderer") == .codex)
        #expect(ProcessScanner.agent(for: "/Applications/ChatGPT.app/Contents/Resources/codex app-server --listen stdio://") == .codex)
        #expect(ProcessScanner.agent(for: "/Users/test/.hermes/node/bin/node /Users/test/project/node_modules/.bin/nuxt dev") == nil)
        #expect(ProcessScanner.agent(for: "/Users/test/.hermes/node/bin/node /Users/test/.local/share/codex-router/server.js") == nil)
        #expect(ProcessScanner.agent(for: "/Applications/Codex Limits.app/Contents/MacOS/Codex Limits") == nil)
    }
}
