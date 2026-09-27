import Foundation

enum ScanConfiguration {
    static var developmentRoot: String {
        let saved = UserDefaults.standard.string(forKey: "developmentRoot")
        return saved ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("dev").path
    }

    static func saveDevelopmentRoot(_ path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard expanded.hasPrefix("/"), FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
        UserDefaults.standard.set(URL(fileURLWithPath: expanded).resolvingSymlinksInPath().path, forKey: "developmentRoot")
        return true
    }
}
