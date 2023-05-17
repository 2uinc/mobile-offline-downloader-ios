import Foundation
public class OfflineStorageDataModel {
    public var id: String
    public var type: String
    public var json: String

    public init(id: String, type: String, json: String) {
        self.id = id
        self.type = type
        self.json = json
    }
}
