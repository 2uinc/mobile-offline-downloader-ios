import Foundation

public enum OfflineDownloaderEntryValue: Equatable {
    case html(html: String, baseURL: String?)
    case url(String)
}

public enum OfflineDownloaderSavedValue: Equatable {
    case html(indexURL: URL, folderURL: URL)
    case localURL(URL)
    case unknown
}

extension OfflineDownloaderEntryValue: Codable {
    private enum CodingKeys : String, CodingKey {
        case type
        case value
        case baseURL
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .html(html, baseURL):
            try container.encode("html", forKey: .type)
            try container.encode(baseURL, forKey: .baseURL)
            try container.encode(html, forKey: .value)
        case let .url(link):
            try container.encode("url", forKey: .type)
            try container.encode(link, forKey: .value)
        
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "html" {
            let baseURL = try? container.decode(String.self, forKey: .baseURL)
            let html = try container.decode(String.self, forKey: .value)
            self = .html(html: html, baseURL: baseURL)
        } else if type == "url" {
            let link = try container.decode(String.self, forKey: .value)
            self = .url(link)
        } else {
            self = .url("") // if type is unknown, then return empty url
        }
    }
}


public class OfflineDownloaderEntryPart: Codable {
    var value: OfflineDownloaderEntryValue
    var links: [OfflineDownloaderLink] = []
    var cookieString: String?

    public init(value: OfflineDownloaderEntryValue) {
        self.value = value
    }
    
    func append(links: [OfflineDownloaderLink]) {
        self.links.append(contentsOf: links)
    }
    
    // MARK: - Codable
    private enum CodingKeys : String, CodingKey {
        case value
        case links
        case cookieString
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(links, forKey: .links)
        try container.encode(cookieString, forKey: .links)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(OfflineDownloaderEntryValue.self, forKey: .value)
        links = try container.decode([OfflineDownloaderLink].self, forKey: .links)
        cookieString = try container.decode(String?.self, forKey: .cookieString)
    }
}

extension OfflineDownloaderEntryPart: Equatable {
    public static func == (lhs: OfflineDownloaderEntryPart, rhs: OfflineDownloaderEntryPart) -> Bool {
        lhs.value == rhs.value && lhs.links == rhs.links
    }
}
