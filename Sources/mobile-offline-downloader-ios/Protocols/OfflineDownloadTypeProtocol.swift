import Foundation

public protocol OfflineDownloadTypeProtocol: OfflineStorageDataProtocol {
    static func canDownload(entry: OfflineDownloaderEntry) -> Bool
    static func prepareForDownload(entry: OfflineDownloaderEntry) async throws
    func downloaderEntry() throws -> OfflineDownloaderEntry
    static func isCritical(error: Error) -> Bool
    static func replaceHTML(tag: String?) async -> String?
}
