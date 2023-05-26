import Foundation

class OfflineVideoDownloader {
    var link: OfflineDownloaderLink
    var progress: Progress = Progress()
    var rootPath: String
    
    init(link: OfflineDownloaderLink, rootPath: String) {
        self.link = link
        self.rootPath = rootPath
    }
    
    func download() async throws {
        guard !link.isDownloaded else { return }
        if link.videoLink == nil {
            try await extractVideoLink(for: link)
        }
        
        let links = [link, link.videoLink?.posterLink].compactMap{$0}
        progress.totalUnitCount = Int64(links.count)
        for link in links {
            try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress)
        }
    }

    private func extractVideoLink(for link: OfflineDownloaderLink) async throws {
        let videoLinkExtractor = VideoLinkExtractor(link: link.link)
        let videoLink = try await videoLinkExtractor.getVideoLink()
        link.extractedLink = videoLink.url
        
        if let posterLink = videoLink.posterLink {
            link.videoLink = OfflineDownloaderVideoLink(posterLink: OfflineDownloaderLink(link: posterLink), videoLink: videoLink)
        } else {
            link.videoLink = OfflineDownloaderVideoLink(posterLink: nil, videoLink: videoLink)
        }

    }
}
