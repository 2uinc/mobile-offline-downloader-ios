import Foundation

struct OfflineCSSLinksExtractor: OfflineLinksExtractorProtocol {
    var contents: String
    var baseUrl: String

    func links() -> [OfflineDownloaderLink] {
        let links = getCssLinks()
            .compactMap { $0.slice(fromStr: "url(", toStr: ")") }
            .map {
                OfflineDownloaderLink(
                    link: $0
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "'", with: "")
                )
            }
        var distinctLinks: [OfflineDownloaderLink] = []
        for link in links {
            distinctLinks.appendDistinct(link)
            link.extractedLink = link.link.fixLink(with: baseUrl)
        }
        
        return distinctLinks
    }
    
    private func getCssLinks() -> [String] {
        let regexp = "url\\(([\\w.,@?^=%&:/~+#-]*[\\w@?^=%&/~+#-])?\\)"
        return resultsFrom(regExp: regexp, inString: contents)
    }
    
    private func resultsFrom(regExp: String, inString: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regExp, options: [.caseInsensitive]) else { return [] }
        let results = regex.matches(in: inString, options: [], range: NSRange(inString.startIndex..., in: inString))
        return results.map {
            if let range = Range($0.range, in: inString) {
                return String(inString[range])
            } else {
                return ""
            }
        }
    }
}
