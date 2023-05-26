import Foundation
class OfflineEntryDownloader {
    var config: OfflineDownloaderConfig
    var entry: OfflineDownloaderEntry
    private var task: Task<(), Never>?

    init(entry: OfflineDownloaderEntry, config: OfflineDownloaderConfig) {
        self.entry = entry
        self.config = config
    }

    func start() {
        task = Task {
            do {
                try await prepare()
                for part in entry.parts {
                    try await download(part: part)
                }
            } catch {
                print("error = \(error)")
            }
        }
    }

    private func download(part: OfflineDownloaderEntryPart) async throws {
        var rootPath = config.rootPath.appendPath(entry.dataModel.type).appendPath(entry.dataModel.id)
        if let index = entry.index(for: part) {
            rootPath += "/\(index)"
        }
        switch part.value {
        case let .html(html, baseURL):
            let extractor = try OfflineHTMLLinksExtractor(html: html, baseURL: baseURL ?? "")
            if part.links.isEmpty {
                let links = try await extractor.links()
                part.append(links: links)
            }
            for link in part.links {
                if !link.isDownloaded {
                    
                    if link.isVideo {
                        // Extract links if need
                    }

                    if link.isIframe {
                        let videoLinkExtractor = VideoLinkExtractor(link: link.link)
                        let videoLink = try await videoLinkExtractor.getVideoLink()
                        link.extractedLink = videoLink.url
                        
                        if let posterString = videoLink.posterLink {
                            let posterLink = OfflineDownloaderLink(link: posterString)
                            try await download(link: posterLink, to: rootPath)
                        }
                        
                        //TODO: download poster, subtitles and replace
                    }
                    print("ALARM: \(link.link.hashValue) \(link.link.sha256())")
                    try await download(link: link, to: rootPath)
                    
                    if link.isCssLink {
                        // Create CSSLoader and wait while it will finish
                        // Parse css
                        // Downoad all css links
                        // Replace links in css to saved links
                        // Copy CSS
                        // Replace css to saved
                        print("CSS link")
                    }
                }
                try extractor.setRelativePath(for: link)
            }
            let html = try extractor.finalHTML()
            let fileName = config.indexFileName
            let path = rootPath.appendPath(fileName)
            try html.write(toFile: path, atomically: true, encoding: .utf8)
        case let.url(url):
            let link = OfflineDownloaderLink(link: url)
            part.append(links: [link])
            try await download(link: link, to: rootPath)
        }
    }
              
    private func download(link: OfflineDownloaderLink, to path: String) async throws {
        let url = try await OfflineLinkDownloader.download(urlString: link.extractedLink ?? link.link, toFolder: path)
        let relativePath = url.filePath.replacingOccurrences(of: path + "/", with: "")
        link.downloadedRelativePath = relativePath
    }

    private func prepare() async throws {
        guard let helperType = config.downloadTypes.first(where: { $0.canDownload(entry: entry) }) else { return }
        try await helperType.prepareForDownload(entry: entry)
    }

    func cancel() {
        task?.cancel()
    }
}
