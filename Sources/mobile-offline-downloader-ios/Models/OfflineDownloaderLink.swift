import SwiftSoup

struct OfflineDownloaderVideoLink: Codable {
    var extractedLink: OfflineDownloaderLink
    var posterLink: OfflineDownloaderLink?
    var videoLink: VideoLink
    
    init(extractedLink: OfflineDownloaderLink, posterLink: OfflineDownloaderLink?, videoLink: VideoLink) {
        self.extractedLink = extractedLink
        self.posterLink = posterLink
        self.videoLink = videoLink
    }
    
    private enum CodingKeys : String, CodingKey {
        case posterLink
        case videoLink
        case extractedLink
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(extractedLink, forKey: .extractedLink)
        try container.encode(posterLink, forKey: .posterLink)
        try container.encode(videoLink, forKey: .videoLink)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extractedLink = try container.decode(OfflineDownloaderLink.self, forKey: .extractedLink)
        posterLink = try container.decode(OfflineDownloaderLink?.self, forKey: .posterLink)
        videoLink = try container.decode(VideoLink.self, forKey: .videoLink)
    }
}

public class OfflineDownloaderLink: Codable {
    public let link: String
    let tag: String?
    let attribute: String?
    let typeAttribute: String?
    var extractedLink: String?
    var downloadedRelativePath: String?
    var videoLinks: [OfflineDownloaderVideoLink]?
    var tagHTML: String?

    public var isWebLink: Bool {
        tag != nil && tag?.isEmpty == false
    }

    public var isCssLink: Bool {
        if tag?.lowercased() == "link" {
            if typeAttribute?.contains("image") == true {
                return false
            }
            return true
        }
        return false
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
        if let videoLinks = videoLinks {
            let links = videoLinks
                .flatMap { [$0.posterLink, $0.extractedLink] }
                .compactMap { $0 }
            let downloadedLinks = links.filter { $0.downloadedRelativePath != nil }
            return downloadedLinks.count == links.count
        }
        return downloadedRelativePath != nil
    }

    init(link: String, tag: String? = nil, attribute: String? = nil, typeAttribute: String? = nil, tagHTML: String? = nil) {
        self.link = link
        self.tag = tag
        self.attribute = attribute
        self.typeAttribute = typeAttribute
        self.tagHTML = tagHTML
    }
    
    private enum CodingKeys : String, CodingKey {
        case link
        case tag
        case attribute
        case extractedLink
        case downloadedRelativePath
        case videoLinks
        case typeAttribute
        case tagHTML
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(link, forKey: .link)
        try container.encode(tag, forKey: .tag)
        try container.encode(attribute, forKey: .attribute)
        try container.encode(extractedLink, forKey: .extractedLink)
        try container.encode(downloadedRelativePath, forKey: .downloadedRelativePath)
        try container.encode(videoLinks, forKey: .videoLinks)
        try container.encode(typeAttribute, forKey: .typeAttribute)
        try container.encode(tagHTML, forKey: .tagHTML)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        link = try container.decode(String.self, forKey: .link)
        tag = try container.decode(String?.self, forKey: .tag)
        attribute = try container.decode(String?.self, forKey: .attribute)
        extractedLink = try container.decode(String?.self, forKey: .extractedLink)
        downloadedRelativePath = try container.decode(String?.self, forKey: .downloadedRelativePath)
        videoLinks = try container.decode([OfflineDownloaderVideoLink]?.self, forKey: .videoLinks)
        typeAttribute = try container.decode(String?.self, forKey: .typeAttribute)
        tagHTML = try container.decode(String?.self, forKey: .tagHTML)
    }
}

extension OfflineDownloaderLink: Equatable {
    public static func == (lhs: OfflineDownloaderLink, rhs: OfflineDownloaderLink) -> Bool {
        lhs.link == rhs.link && lhs.tag == rhs.tag &&
        lhs.attribute == rhs.attribute && lhs.extractedLink == rhs.extractedLink &&
        lhs.downloadedRelativePath == rhs.downloadedRelativePath
    }
    
    
}
