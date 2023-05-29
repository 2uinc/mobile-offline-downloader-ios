import Foundation
import RealmSwift

public final class OfflineStorageDataModel: StoreObject, Storable, Codable {
    @Persisted public var type: String
    @Persisted public var json: String

    public convenience init(id: String, type: String, json: String) {
        self.init()
        self.id = id
        self.type = type
        self.json = json
    }
    
    public override init() {
        type = ""
        json = ""
    }
    
    // MARK: - Codable
    private enum CodingKeys : String, CodingKey {
        case id
        case type
        case json
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(json, forKey: .json)
    }
    
    public required init(from decoder: Decoder) throws {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        json = try container.decode(String.self, forKey: .json)
    }
}
