import AppKit
import Foundation

enum AppResources {
    static func image(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    static func duotoneIcon(named name: String, pointSize: CGFloat) -> NSImage? {
        guard let image = image(named: "ph-\(name)") else { return nil }
        // AppKit pickers use the image's intrinsic size rather than SwiftUI's frame.
        image.size = NSSize(width: pointSize, height: pointSize)
        image.isTemplate = true
        return image
    }

    static func icon(for agent: AgentKind) -> NSImage? {
        let name = agent.iconResourceName
        let roots = [Bundle.main.resourceURL, Bundle.main.executableURL?.deletingLastPathComponent()].compactMap { $0 }
        for root in roots {
            let url = root.appendingPathComponent("CleanMyAgent_CleanMyAgentCore.bundle")
            if let bundle = Bundle(url: url), let imageURL = bundle.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: imageURL) { return image }
            if let image = NSImage(contentsOf: url.appendingPathComponent("\(name).png")) { return image }
        }
        return nil
    }
}
