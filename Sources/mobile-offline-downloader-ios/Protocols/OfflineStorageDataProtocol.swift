import Foundation

public protocol OfflineStorageDataProtocol {
    func toOfflineModel() -> OfflineStorageDataModel
    static func fromOfflineModel(_ model: OfflineStorageDataModel) -> Self?
}

//protocol OfflineStorageHelperProtocol {
//    associatedtype OfflineObject
//
//    func toOfflineModel<T: OfflineStorageDataModel>(_ object: T) -> OfflineStorageDataModel
//    func fromOfflineModel(_ model: OfflineStorageDataModel) -> OfflineObject?
//}
//
//extension OfflineStorageDataProtocol {
//    var offlineType: OfflineObject.Type {
//        OfflineObject.self
//    }
//}
