import Foundation

public enum OfflineDownloaderEntryValue {
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
