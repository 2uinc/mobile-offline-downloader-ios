import Foundation

public final class OfflineDownloaderEntry: Codable {
    public var dataModel: OfflineStorageDataModel
    public var parts: [OfflineDownloaderEntryPart]
    public var userInfo: String?
    public var cookieString: String?
    var isDownloaded: Bool = false

    public init(dataModel: OfflineStorageDataModel, parts: [OfflineDownloaderEntryPart]) {
        self.dataModel = dataModel
        self.parts = parts
    }

    public func addHtmlPart(_ html: String, baseURL: String?, cookieString: String? = nil) {
        let part = OfflineDownloaderEntryPart(value: .html(html: html, baseURL: baseURL))
        part.cookieString = cookieString
        parts.append(part)
    }

    public func addURLPart(_ link: String) {
        let part = OfflineDownloaderEntryPart(value: .url(link))
        parts.append(part)
    }
    
    public func index(for part: OfflineDownloaderEntryPart) -> Int? {
        return parts.firstIndex(of: part)
    }
    
    public func rootPath(with mainPath: String) -> String {
        mainPath.appendPath(dataModel.type).appendPath(dataModel.id)
    }

    public func set(userInfo: String?) {
        self.userInfo = userInfo
    }

    // MARK: - Codable
    private enum CodingKeys : String, CodingKey {
        case dataModel
        case parts
        case isDownloaded
        case userInfo
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dataModel, forKey: .dataModel)
        try container.encode(parts, forKey: .parts)
        try container.encode(isDownloaded, forKey: .isDownloaded)
        try container.encode(userInfo, forKey: .userInfo)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataModel = try container.decode(OfflineStorageDataModel.self, forKey: .dataModel)
        parts = try container.decode([OfflineDownloaderEntryPart].self, forKey: .parts)
        isDownloaded = try container.decode(Bool.self, forKey: .isDownloaded)
        userInfo = try container.decode(String?.self, forKey: .userInfo)
    }
}

extension OfflineDownloaderEntry: OfflineStorageDataProtocol {
    public func toOfflineModel() throws -> OfflineStorageDataModel {
        let encoder = JSONEncoder()
        let json = try encoder.encode(self)
        guard let jsonString = String(data: json, encoding: .utf8) else {
            throw OfflineStorageDataError.cantConvertToData
        }
        return OfflineStorageDataModel(id: dataModel.id + "_" + dataModel.type , type: "OfflineStorageDataModel", json: jsonString)
    }
    
    public static func fromOfflineModel(_ model: OfflineStorageDataModel) throws -> OfflineDownloaderEntry {
        let decoder = JSONDecoder()
        guard let data = model.json.data(using: .utf8) else {
            throw OfflineStorageDataError.cantCreateObject(type: OfflineDownloaderEntry.self)
        }
        let entry = try decoder.decode(OfflineDownloaderEntry.self, from: data)
        return entry
    }
}
