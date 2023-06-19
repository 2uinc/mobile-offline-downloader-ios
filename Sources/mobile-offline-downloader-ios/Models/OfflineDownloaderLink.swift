import SwiftSoup

struct OfflineDownloaderVideoLink: Codable {
    var posterLink: OfflineDownloaderLink?
    var videoLink: VideoLink
    
    init(posterLink: OfflineDownloaderLink?, videoLink: VideoLink) {
        self.posterLink = posterLink
        self.videoLink = videoLink
    }
    
    private enum CodingKeys : String, CodingKey {
        case posterLink
        case videoLink
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(posterLink, forKey: .posterLink)
        try container.encode(videoLink, forKey: .videoLink)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        posterLink = try container.decode(OfflineDownloaderLink?.self, forKey: .posterLink)
        videoLink = try container.decode(VideoLink.self, forKey: .videoLink)
    }
}

public class OfflineDownloaderLink: Codable {
    public let link: String
    let tag: String?
    let attribute: String?
    var extractedLink: String?
    var downloadedRelativePath: String?
    var videoLink: OfflineDownloaderVideoLink?

    public var isWebLink: Bool {
        tag != nil && tag?.isEmpty == false
    }

    public var isCssLink: Bool {
        tag?.lowercased() == "link"
    }

    public var isIframe: Bool {
        tag?.lowercased() == "iframe"
    }
    
    public var isScript: Bool {
        tag?.lowercased() == "script"
    }

    public var isVideo: Bool {
        tag?.lowercased() == "video"
    }

    public var isAudio: Bool {
        tag?.lowercased() == "audio"
    }

    public var isImage: Bool {
        tag?.lowercased() == "img"
    }

    public var isSource: Bool {
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
        case videoLink
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(link, forKey: .link)
        try container.encode(tag, forKey: .tag)
        try container.encode(attribute, forKey: .attribute)
        try container.encode(extractedLink, forKey: .extractedLink)
        try container.encode(downloadedRelativePath, forKey: .downloadedRelativePath)
        try container.encode(videoLink, forKey: .videoLink)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        link = try container.decode(String.self, forKey: .link)
        tag = try container.decode(String?.self, forKey: .tag)
        attribute = try container.decode(String?.self, forKey: .attribute)
        extractedLink = try container.decode(String?.self, forKey: .extractedLink)
        downloadedRelativePath = try container.decode(String?.self, forKey: .downloadedRelativePath)
        videoLink = try container.decode(OfflineDownloaderVideoLink?.self, forKey: .videoLink)
    }
}

extension OfflineDownloaderLink: Equatable {
    public static func == (lhs: OfflineDownloaderLink, rhs: OfflineDownloaderLink) -> Bool {
        lhs.link == rhs.link && lhs.tag == rhs.tag &&
        lhs.attribute == rhs.attribute && lhs.extractedLink == rhs.extractedLink &&
        lhs.downloadedRelativePath == rhs.downloadedRelativePath
    }
    
    
}
