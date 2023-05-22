import Foundation

public protocol OfflineDownloadTypeProtocol {
    static func canDownload(entry: OfflineDownloaderEntry) -> Bool
    static func prepareForDownload(entry: OfflineDownloaderEntry) async throws
}
