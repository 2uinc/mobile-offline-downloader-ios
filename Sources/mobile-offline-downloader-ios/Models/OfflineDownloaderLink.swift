import SwiftSoup

class OfflineDownloaderLink {
    let link: String
    let tag: String?
    let attribute: String?
    var extractedLink: String?
    var downloadedLink: String?

    var isWebLink: Bool {
        tag != nil && tag?.isEmpty == false
    }

    var isCssLink: Bool {
        tag?.lowercased() == "link"
    }

    var isIframe: Bool {
        tag?.lowercased() == "iframe"
    }

    var isVideo: Bool {
        tag?.lowercased() == "video"
    }

    var isAudio: Bool {
        tag?.lowercased() == "audio"
    }

    var isImage: Bool {
        tag?.lowercased() == "img"
    }

    var isSource: Bool {
        tag?.lowercased() == "source"
    }

    var isDownloaded: Bool {
        downloadedLink != nil
    }

    init(link: String, tag: String?, attribute: String?) {
        self.link = link
        self.tag = tag
        self.attribute = attribute
    }
}
