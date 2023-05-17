import Foundation

enum OfflineDownloaderEntryValue {
    case html(html: String, baseURL: String?)
    case url(String)
}

class OfflineDownloaderEntryPart {
    var value: OfflineDownloaderEntryValue
    var links: [OfflineDownloaderLink] = []

    init(value: OfflineDownloaderEntryValue) {
        self.value = value
    }
    
    func append(links: [OfflineDownloaderLink]) {
        self.links.append(contentsOf: links)
    }
}
