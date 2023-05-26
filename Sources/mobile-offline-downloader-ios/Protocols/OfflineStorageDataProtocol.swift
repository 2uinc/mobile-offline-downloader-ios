import Foundation

public protocol OfflineStorageDataProtocol {
    func toOfflineModel() throws -> OfflineStorageDataModel
    static func fromOfflineModel(_ model: OfflineStorageDataModel) throws -> Self
}

public enum OfflineStorageDataError: Error, LocalizedError {
    case cantConvertToData
    case cantCreateObject(type: Any.Type)
    
    public var errorDescription: String? {
        switch self {
        case .cantConvertToData:
            return "Can't convert to data object."
        case let .cantCreateObject(type: type):
            return "Can't create object \(type) from data."
        }
    }
}
