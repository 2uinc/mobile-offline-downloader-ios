import Foundation

public class OfflineStorageManager {
    public static let shared: OfflineStorageManager = .init()
    private var config: OfflineStorageConfig = OfflineStorageConfig()

    public func setConfig(config: OfflineStorageConfig) {
        self.config = config
    }

    public func save<T: OfflineStorageDataProtocol>(_ object: T) {
        let data = dataModel(for: object)
        // TODO: Save to database
    }

    public func load<T: OfflineStorageDataProtocol>(for id: String, castingType: T.Type) -> T? {
        let typeString = String(describing: castingType)
        // TODO: get data from database for id and typeString
        let data = OfflineStorageDataModel(id: "testId", type: typeString, json: "{}")
        return object(from: data, for: castingType)
    }

    public func loadAll<T:OfflineStorageDataProtocol>(of type: T.Type) -> [T] {
        let typeString = String(describing: type)
        // TODO: load all entries for type = typeString
        return []
    }

    public func dataModel<T:OfflineStorageDataProtocol>(for object: T) -> OfflineStorageDataModel? {
        object.toOfflineModel()
    }

    public func object<T: OfflineStorageDataProtocol>(from data: OfflineStorageDataModel, for type: T.Type) -> T? {
        type.fromOfflineModel(data)
    }
}
