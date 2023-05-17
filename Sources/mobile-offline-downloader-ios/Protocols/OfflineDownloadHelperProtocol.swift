import Foundation

public protocol OfflineDownloadHelperProtocol {
    static func prepareForDownload(entry: OfflineDownloaderEntry) async throws
}
