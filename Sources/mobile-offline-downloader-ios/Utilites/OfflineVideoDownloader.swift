import Foundation

class OfflineVideoDownloader {
    struct OfflineVideoDownloaderResult {
        var link: OfflineDownloaderLink
        var poster: OfflineDownloaderLink?
        var videoLink: VideoLink
    }
    
    var link: OfflineDownloaderLink
    var progress: Progress = Progress()
    var rootPath: String
    
    init(link: OfflineDownloaderLink, rootPath: String) {
        self.link = link
        self.rootPath = rootPath
    }
    
    func download() async throws -> OfflineVideoDownloaderResult {
        var links = [link]
        let videoLinkExtractor = VideoLinkExtractor(link: link.link)
        let videoLink = try await videoLinkExtractor.getVideoLink()
        link.extractedLink = videoLink.url
        
        var result = OfflineVideoDownloaderResult(link: link, videoLink: videoLink)
        
        if let posterString = videoLink.posterLink {
            let posterLink = OfflineDownloaderLink(link: posterString)
            links.append(link)
            result.poster = posterLink
        }
        
        progress.totalUnitCount = Int64(links.count)
        for link in links {
            let downloader = OfflineLinkDownloader()
            progress.addChild(downloader.progress, withPendingUnitCount: 1)
            let url = try await downloader.download(urlString: link.extractedLink ?? link.link, toFolder: rootPath)
            let relativePath = url.filePath.replacingOccurrences(of: rootPath + "/", with: "")
            link.downloadedRelativePath = relativePath
        }
        
        return result
    }
    
}
