import Foundation

public protocol OfflineStorageDataProtocol {
    func toOfflineModel() -> OfflineStorageDataModel
    static func fromOfflineModel(_ model: OfflineStorageDataModel) -> Self?
}
