import AppKit
import Foundation

enum AppResources {
    static func icon(for agent: AgentKind) -> NSImage? {
        let name = agent.iconResourceName
        let roots = [Bundle.main.resourceURL, Bundle.main.executableURL?.deletingLastPathComponent()].compactMap { $0 }
        for root in roots {
            let url = root.appendingPathComponent("CleanMyAgent_AgentSpace.bundle")
            if let bundle = Bundle(url: url), let imageURL = bundle.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: imageURL) { return image }
            if let image = NSImage(contentsOf: url.appendingPathComponent("\(name).png")) { return image }
        }
        return nil
    }
}
