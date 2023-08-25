import Foundation
struct OfflineErrorHandler {
    let config: OfflineDownloaderConfig
    let entry: OfflineDownloaderEntry
    
    var handler: OfflineDownloadTypeProtocol.Type? {
        return config.downloadTypes.first(where: { $0.canDownload(entry: entry) })
    }

    var nonCriticalError: Error? {
        guard !entry.errors.isEmpty else { return nil }
        return OfflineErrorHandlerError.nonCriticalErrors(errors: entry.errors, dataModel: entry.dataModel)
    }

    func perform<T>(_ block: () async throws -> T, ignore: () async throws -> T) async throws -> T {
        do {
            return try await block()
        } catch {
            try throwErrorIfNeed(for: error)
            return try await ignore()
        }
    }

    func perform(_ block: () async throws -> Void) async throws {
        do {
            try await block()
        } catch {
            try throwErrorIfNeed(for: error)
        }
    }

    func appendError(_ error: Error) {
        if error is OfflineErrorHandlerError { return }
        entry.errors.append(error)
    }

    private func throwErrorIfNeed(for error: Error) throws {
        guard let handler = handler else {
            throw OfflineErrorHandlerError.unsupported
        }

        if error.isOfflineCancel {
            throw error
        }
        appendError(error)
        if error is OfflineErrorHandlerError ||
            handler.isCritical(error: error) {
            throw OfflineErrorHandlerError.errors(errors: entry.errors, dataModel: entry.dataModel)
        }
    }
}

extension OfflineErrorHandler {
    enum OfflineErrorHandlerError: Error, LocalizedError {
        case unsupported
        case errors(errors: [Error], dataModel: OfflineStorageDataModel)
        case nonCriticalErrors(errors: [Error], dataModel: OfflineStorageDataModel)

        var errorDescription: String? {
            switch self {
            case .unsupported:
                return "Entry unsupported."
            case let .nonCriticalErrors(errors, dataModel):
                return "Did found non critical errors. Errors: \(errors). Model: \(dataModel.json)"
            case let .errors(errors, dataModel):
                return "Did found critical error. Errors: \(errors). Model: \(dataModel.json)"
            }
        }
    }
}
 
