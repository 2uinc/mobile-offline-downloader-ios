import Foundation

extension Array where Element: HTTPCookie {
    public var cookieString: String? {
        guard !self.isEmpty else { return nil }
        var result = ""
        for cookie in self {
            result += result.isEmpty ? "\(cookie.name)=\(cookie.value)" : "; \(cookie.name)=\(cookie.value)"
        }
        return result
    }
}
