import Foundation

public final class OfflineDownloaderEntry: Codable {
    public var dataModel: OfflineStorageDataModel
    public var parts: [OfflineDownloaderEntryPart]
    public var userInfo: String?
    @objc public dynamic var status: OfflineDownloaderStatus = .initialized
    var errors: [Error] = []
    private(set) var isForcePaused: Bool = false
    var isUnsupported: Bool = false
    var isServerError: Bool = false
    let createdDate: Double

    public init(dataModel: OfflineStorageDataModel, parts: [OfflineDownloaderEntryPart]) {
        self.dataModel = dataModel
        self.parts = parts
        self.createdDate = Date().timeIntervalSince1970
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
    
    public func markAsUnsupported() {
        isUnsupported = true
    }

    public func markAsServerError() {
        isServerError = true
    }

    public func setForcePaused(_ value: Bool) {
        isForcePaused = value
    }
    // MARK: - Codable
    private enum CodingKeys : String, CodingKey {
        case dataModel
        case parts
        case isDownloaded
        case userInfo
        case status
        case errors
        case isForcePaused
        case createdDate
        case isUnsupported
        case isServerError
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dataModel, forKey: .dataModel)
        try container.encode(parts, forKey: .parts)
        try container.encode(userInfo, forKey: .userInfo)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(isForcePaused, forKey: .isForcePaused)
        try container.encode(isUnsupported, forKey: .isUnsupported)
        try container.encode(isServerError, forKey: .isServerError)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataModel = try container.decode(OfflineStorageDataModel.self, forKey: .dataModel)
        parts = try container.decode([OfflineDownloaderEntryPart].self, forKey: .parts)
        userInfo = try container.decode(String?.self, forKey: .userInfo)
        let statusRawValue = try container.decode(Int.self, forKey: .status)
        status = OfflineDownloaderStatus(rawValue: statusRawValue) ?? .initialized
        createdDate = try container.decode(Double.self, forKey: .createdDate)
        isForcePaused = try container.decode(Bool.self, forKey: .isForcePaused)
        isUnsupported = try container.decode(Bool.self, forKey: .isUnsupported)
        isServerError = try container.decode(Bool.self, forKey: .isServerError)
    }
    
    // MARK: Storage
    func saveToDB() async throws {
        try await withCheckedThrowingContinuation { continuation in
            saveToDB { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func saveToDB(completion: @escaping (Result<Void, Error>) -> Void) {
        OfflineStorageManager.shared.save(self) { result in
            completion(result)
        }
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
