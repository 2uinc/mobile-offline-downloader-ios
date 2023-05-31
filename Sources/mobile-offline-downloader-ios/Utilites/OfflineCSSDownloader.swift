import Foundation

class OfflineCSSLinkDownloader {
    var link: OfflineDownloaderLink
    var rootPath: String
    var shouldCache: Bool
    var progress: Progress = Progress()
    
    init(link: OfflineDownloaderLink, rootPath: String, shouldCache: Bool) {
        self.link = link
        self.rootPath = rootPath
        self.shouldCache = shouldCache
    }

    func download() async throws {
        // TODO: implement shouldCache CSS 
        progress.totalUnitCount = 2
        try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress)
        
        if let relativePath = link.downloadedRelativePath {
            let path = rootPath.appendPath(relativePath)
            let cssFolder = path.removeLastPathComponent()
            var contents = try String(contentsOf: path.fileURL())
            let baseURL = link.link
            let links = OfflineCSSLinksExtractor(contents: contents, baseUrl: baseURL).links()
            let linksProgress = Progress()
            linksProgress.totalUnitCount = Int64(links.count)
            progress.addChild(linksProgress, withPendingUnitCount: 1)
            for link in links.sorted(by: { $0.link.count > $1.link.count }) {
                try await OfflineLinkDownloader.download(link: link, to: cssFolder, with: linksProgress)
                if let downloadedPath = link.downloadedRelativePath, let encodedLink = downloadedPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                    contents = contents.replacingOccurrences(of: link.link, with: encodedLink)
                }
            }
            try FileManager.default.removeItem(atPath: path)
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
        }

        progress.completedUnitCount = 2
    }
}
