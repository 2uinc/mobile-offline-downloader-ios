import Foundation

public extension Error {
    var isOfflineCancel: Bool {
        return isCancelled || isNotConnected
    }
    
    var isCancelled: Bool {
        if let error = self as? URLError, error.code == .cancelled {
            return true
        }
        return false
    }

    var isNotConnected: Bool {
        if let error = self as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        return false
    }
}

