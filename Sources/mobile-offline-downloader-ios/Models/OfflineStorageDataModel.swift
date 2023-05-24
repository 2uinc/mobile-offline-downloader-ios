import Foundation
import RealmSwift

public final class OfflineStorageDataModel: StoreObject, Storable {
    @Persisted public var type: String
    @Persisted public var json: String

    public convenience init(id: String, type: String, json: String) {
        self.init()
        self.id = id
        self.type = type
        self.json = json
    }
}
