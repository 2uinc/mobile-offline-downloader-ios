import SwiftSoup

class OfflineDownloaderLink {
    let link: String
    let tag: String?
    let attribute: String?
    var extractedLink: String?
    var downloadedRelativePath: String?

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
        downloadedRelativePath != nil
    }

    init(link: String, tag: String? = nil, attribute: String? = nil) {
        self.link = link
        self.tag = tag
        self.attribute = attribute
    }
}

extension OfflineDownloaderLink: Equatable {
    static func == (lhs: OfflineDownloaderLink, rhs: OfflineDownloaderLink) -> Bool {
        lhs.link == rhs.link && lhs.tag == rhs.tag &&
        lhs.attribute == rhs.attribute && lhs.extractedLink == rhs.extractedLink &&
        lhs.downloadedRelativePath == rhs.downloadedRelativePath
    }
    
    
}
