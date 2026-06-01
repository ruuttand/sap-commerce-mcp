import Foundation
import CryptoKit

enum MD5Helper {
    // Returns the full 32-char hex MD5 digest.
    // Ruby uses Digest::MD5.hexdigest(path)[0..8] — indices 0..8 inclusive = 9 chars.
    static func hash(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func dbHash(_ projectPath: String) -> String {
        String(hash(projectPath).prefix(9))
    }
}
