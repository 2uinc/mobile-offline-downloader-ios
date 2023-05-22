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
                    try await download(link: link, to: rootPath)
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
        if link.isCssLink {
            // Create CSSLoader and wait while it will finish
            print("CSS link")
        } else if link.isVideo {
            // Extract links if need
        } else if link.isIframe {
            // Extract link if need
        } else {
            let url = try await OfflineLinkDownloader.download(urlString: link.link, toFolder: path)
            let relativePath = url.filePath.replacingOccurrences(of: path + "/", with: "")
            link.downloadedRelativePath = relativePath
        }
    }

    private func prepare() async throws {
        guard let helperType = config.downloadTypes.first(where: { $0.canDownload(entry: entry) }) else { return }
        try await helperType.prepareForDownload(entry: entry)
    }

    func cancel() {
        task?.cancel()
    }
}
