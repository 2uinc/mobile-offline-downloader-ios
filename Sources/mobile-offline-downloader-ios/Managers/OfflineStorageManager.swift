import Foundation

public class OfflineStorageManager {
    
    public static let shared: OfflineStorageManager = .init()
    private var storage: LocalStorage = .current
    private var config: OfflineStorageConfig = OfflineStorageConfig()

    public func setConfig(config: OfflineStorageConfig) {
        self.config = config
    }

    public func save<T: OfflineStorageDataProtocol>(
        _ object: T,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let data = dataModel(for: object) else {
            completionHandler(.failure(OfflineStorageManagerError.text("Data model error")))
            return
        }
        storage.addOrUpdate(value: data, completionHandler: completionHandler)
    }

    public func delete<T: OfflineStorageDataProtocol>(
        _ object: T,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let data = dataModel(for: object) else {
            completionHandler(.failure(OfflineStorageManagerError.text("Data model error")))
            return
        }
       storage.delete(OfflineStorageDataModel.self, value: data, completionHandler: completionHandler)
    }

    public func delete<T: OfflineStorageDataProtocol>(
        _ objects: [T],
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        let data = objects.compactMap { dataModel(for: $0) }
        storage.delete(OfflineStorageDataModel.self, values: data, completionHandler: completionHandler)
    }

    public func load<T: OfflineStorageDataProtocol>(
        for id: String,
        castingType: T.Type,
        completionHandler: @escaping (Result<T?, Error>) -> Void
    ) {
        storage.object(OfflineStorageDataModel.self, forPrimaryKey: id) { [weak self] value in
            guard let self = self, let data = value else {
                return
            }
            let object = self.object(from: data, for: castingType)
            completionHandler(.success(object))
        }
    }

    public func isSaved(
        for id: String,
        completionHandler: @escaping (Bool) -> Void
    ) {
        storage.object(OfflineStorageDataModel.self, forPrimaryKey: id) { value in
            completionHandler(value != nil)
        }
    }

    public func loadAll<T:OfflineStorageDataProtocol>(
        of type: T.Type,
        completionHandler: @escaping (Result<[T], Error>) -> Void
    )  {
        storage.objects(OfflineStorageDataModel.self) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let data):
                completionHandler(.success(data.compactMap { self.object(from: $0, for: type) }))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    public func dataModel<T:OfflineStorageDataProtocol>(for object: T) -> OfflineStorageDataModel? {
        object.toOfflineModel()
    }

    public func object<T: OfflineStorageDataProtocol>(from data: OfflineStorageDataModel, for type: T.Type) -> T? {
        type.fromOfflineModel(data)
    }
}

enum OfflineStorageManagerError: Error {
    case text(String)
    case error
}

extension OfflineStorageManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .text(let text):
            return text
        case .error:
            return "OfflineStorageManager error"
        }
    }
}
