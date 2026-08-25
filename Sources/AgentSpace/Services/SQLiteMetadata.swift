import Foundation

enum SQLiteMetadata {
    static func query(database: String, sql: String, timeout: TimeInterval = 3) -> [[String: Any]]? {
        guard FileManager.default.fileExists(atPath: database) else { return nil }
        let result = Shell.run(
            "/usr/bin/sqlite3",
            ["-readonly", "-json", "-cmd", ".timeout 250", database, sql],
            timeout: timeout
        )
        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return rows
    }
}
