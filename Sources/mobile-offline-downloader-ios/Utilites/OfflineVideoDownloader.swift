import Foundation

class OfflineVideoDownloader {
    var link: OfflineDownloaderLink
    var progress: Progress = Progress()
    var rootPath: String
    var cookieString: String?
    
    init(link: OfflineDownloaderLink, rootPath: String) {
        self.link = link
        self.rootPath = rootPath
    }
    
    func download() async throws {
        guard !link.isDownloaded else { return }
        if link.videoLinks == nil {
            try await extractVideoLink(for: link)
        }
        
        guard let videoLinks = link.videoLinks else { return }
        
        let links = videoLinks
            .flatMap { [$0.posterLink, $0.extractedLink] }
            .compactMap{ $0 }
        progress.totalUnitCount = Int64(links.count)
        for link in links {
            try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress, cookieString: cookieString)
        }
    }

    private func extractVideoLink(for link: OfflineDownloaderLink) async throws {
        let videoLinkExtractor = VideoLinkExtractor(link: link, cookieString: cookieString)
        let videoLinks = try await videoLinkExtractor.getVideoLinks()
        link.videoLinks = videoLinks.map({ videoLink in
            let extractedLink = OfflineDownloaderLink(link: videoLink.url)
            var posterLink: OfflineDownloaderLink?
            if let url = videoLink.posterLink {
                posterLink = OfflineDownloaderLink(link: url)
            }
            return OfflineDownloaderVideoLink(extractedLink: extractedLink, posterLink: posterLink, videoLink: videoLink)
        })
    }
}
