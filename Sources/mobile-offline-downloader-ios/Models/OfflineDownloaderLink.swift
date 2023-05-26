import SwiftSoup

class OfflineDownloaderLink: Codable {
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
    
    private enum CodingKeys : String, CodingKey {
        case link
        case tag
        case attribute
        case extractedLink
        case downloadedRelativePath
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(link, forKey: .link)
        try container.encode(tag, forKey: .tag)
        try container.encode(attribute, forKey: .attribute)
        try container.encode(extractedLink, forKey: .extractedLink)
        try container.encode(downloadedRelativePath, forKey: .downloadedRelativePath)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        link = try container.decode(String.self, forKey: .link)
        tag = try container.decode(String?.self, forKey: .tag)
        attribute = try? container.decode(String.self, forKey: .attribute)
        extractedLink = try? container.decode(String.self, forKey: .extractedLink)
        downloadedRelativePath = try? container.decode(String.self, forKey: .downloadedRelativePath)
    }
}

extension OfflineDownloaderLink: Equatable {
    static func == (lhs: OfflineDownloaderLink, rhs: OfflineDownloaderLink) -> Bool {
        lhs.link == rhs.link && lhs.tag == rhs.tag &&
        lhs.attribute == rhs.attribute && lhs.extractedLink == rhs.extractedLink &&
        lhs.downloadedRelativePath == rhs.downloadedRelativePath
    }
    
    
}
