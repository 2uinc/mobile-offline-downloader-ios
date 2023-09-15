import Foundation
import RealmSwift

public final class OfflineStorageDataModel: StoreObject, Storable, Codable {
    @Persisted public var type: String
    @Persisted public var json: String
    @Persisted public var containerID: String = ""

    public convenience init(id: String, type: String, json: String, containerID: String) {
        self.init()
        self.id = id
        self.type = type
        self.json = json
        self.uniqueId = OfflineStorageDataModel.uniqueId(from: id, containerID: containerID)
    }
    
    public override init() {
        type = ""
        json = ""
    }
    
    static func uniqueId(from id: String, containerID: String) -> String {
        containerID + "_" + id
    }
    
    // MARK: - Codable
    private enum CodingKeys : String, CodingKey {
        case id
        case type
        case json
        case containerID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(json, forKey: .json)
        try container.encode(containerID, forKey: .containerID)
    }
    
    public required init(from decoder: Decoder) throws {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        json = try container.decode(String.self, forKey: .json)
        containerID = try container.decode(String.self, forKey: .containerID)
    }
}
