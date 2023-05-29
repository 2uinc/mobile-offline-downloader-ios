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
        do {
            let data = try dataModel(for: object)
            storage.addOrUpdate(value: data, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }

    public func delete<T: OfflineStorageDataProtocol>(
        _ object: T,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            let data = try dataModel(for: object)
            storage.delete(OfflineStorageDataModel.self, value: data, completionHandler: completionHandler)
        }catch {
            completionHandler(.failure(error))
        }
    }

    public func delete<T: OfflineStorageDataProtocol>(
        _ objects: [T],
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            let data = try objects.compactMap { try dataModel(for: $0) }
            storage.delete(OfflineStorageDataModel.self, values: data, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }

    public func load<T: OfflineStorageDataProtocol>(
        for id: String,
        castingType: T.Type,
        completionHandler: @escaping (Result<T, Error>) -> Void
    ) {
        storage.object(OfflineStorageDataModel.self, forPrimaryKey: id) { [weak self] value in
            guard let self = self, let data = value else {
                return
            }
            do {
                let object = try self.object(from: data, for: castingType)
                completionHandler(.success(object))
            } catch {
                completionHandler(.failure(error))
            }
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
                do {
                    completionHandler(.success(try data.compactMap { try self.object(from: $0, for: type) }))
                } catch {
                    completionHandler(.failure(error))
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    public func dataModel<T:OfflineStorageDataProtocol>(for object: T) throws -> OfflineStorageDataModel {
        try object.toOfflineModel()
    }

    public func object<T: OfflineStorageDataProtocol>(from data: OfflineStorageDataModel, for type: T.Type) throws -> T {
        try type.fromOfflineModel(data)
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
