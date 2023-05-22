import Foundation

extension String {
    var trim: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func slice(fromStr: String, toStr: String) -> String? {
        guard let rangeFrom = range(of: fromStr)?.upperBound else { return nil }
        guard let rangeTo = self[rangeFrom...].range(of: toStr)?.lowerBound else { return nil }
        return String(self[rangeFrom ..< rangeTo])
    }

    func appendPath( _ path: String) -> String {
        var rootComponents = components(separatedBy: "/")
        let pathComponents = path.components(separatedBy: "/")
            .filter { !$0.isEmpty }
        rootComponents.append(contentsOf: pathComponents)
        return rootComponents.joined(separator: "/")
    }

    func removeLastPathComponent() -> String {
        var pathComponents = self.components(separatedBy: "/")
        pathComponents.removeLast()
        return pathComponents.joined(separator: "/")
    }

    func lastPathComponent() -> String {
        components(separatedBy: "/").last ?? self
    }

    func removeNewLines() -> String {
        self.replacingOccurrences(of: "\n", with: "")
    }
    
    func fixLink(with baseUrlString: String) -> String {
        let trimString = self.trim.removeNewLines()
        let url = URL(string: trimString, relativeTo: URL(string: baseUrlString))
        if let url = url {
            if url.scheme == nil && url.absoluteString.prefix(2) == "//" {
                return "https:" + url.absoluteString
            }
            return url.absoluteString
        } else {
            if trimString.prefix(2) == "//" {
                return "https:" + trimString
            } else {
                return trimString
            }
        }
    }
}

import CryptoKit
extension String {
    func sha256() -> String? {
        guard let data = data(using: .utf8) else { return nil }
        let hashData = SHA256.hash(data: data)
        return hashData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
