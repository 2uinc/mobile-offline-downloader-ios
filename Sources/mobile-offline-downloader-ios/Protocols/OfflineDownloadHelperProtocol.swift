import Foundation

public protocol OfflineDownloadHelperProtocol {
    static func canDownload(entry: OfflineDownloaderEntry) -> Bool
    static func prepareForDownload(entry: OfflineDownloaderEntry) async throws
}
