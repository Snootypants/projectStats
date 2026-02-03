import Foundation
import CryptoKit

extension String {
    var sha256Hash: String {
        let data = Data(utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
