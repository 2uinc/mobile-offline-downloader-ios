import Foundation

public enum OfflineDownloaderEntryValue: Equatable {
    case html(html: String, baseURL: String?)
    case url(String)
}

public class OfflineDownloaderEntryPart {
    var value: OfflineDownloaderEntryValue
    var links: [OfflineDownloaderLink] = []

    public init(value: OfflineDownloaderEntryValue) {
        self.value = value
    }
    
    func append(links: [OfflineDownloaderLink]) {
        self.links.append(contentsOf: links)
    }
}

extension OfflineDownloaderEntryPart: Equatable {
    public static func == (lhs: OfflineDownloaderEntryPart, rhs: OfflineDownloaderEntryPart) -> Bool {
        lhs.value == rhs.value && lhs.links == rhs.links
    }
}
