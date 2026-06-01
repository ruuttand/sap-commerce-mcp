import Foundation
import CryptoKit

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }

    var dbPath: String {
        let hash = MD5Helper.hash(path).prefix(9)
        let base = ("~/.sap-commerce-mcp/indexes" as NSString).expandingTildeInPath
        return "\(base)/\(hash).db"
    }

    var dbExists: Bool {
        FileManager.default.fileExists(atPath: dbPath)
    }

    var displayName: String {
        name.isEmpty ? (path as NSString).lastPathComponent : name
    }
}
