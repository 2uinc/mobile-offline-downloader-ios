import Foundation
protocol OfflineLinksExtractorProtocol {
    func links() async throws -> [OfflineDownloaderLink]
}
