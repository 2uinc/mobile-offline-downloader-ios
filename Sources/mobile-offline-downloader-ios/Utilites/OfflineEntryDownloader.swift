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
        var rootPath = config.rootPath + "/\(entry.dataModel.type)" + "\(entry.dataModel.id)"
        if let index = entry.index(for: part) {
            rootPath += "/\(index)"
        }
        switch part.value {
        case let .html(html, baseURL):
            if part.links.isEmpty {
                let links = try await OfflineHTMLLinksExtractor(html: html, baseURL: baseURL ?? "").links()
                part.append(links: links)
            }
            for link in part.links where !link.isDownloaded {
                try await download(link: link, to: rootPath)
            }
            print(html)
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
            let relativePath = url.absoluteString.replacingOccurrences(of: path + "/", with: "")
            link.downloadedRelativePath = relativePath
        }
    }

    private func prepare() async throws {
        guard let helperType = config.downloadHelpers.first(where: { $0.canDownload(entry: entry) }) else { return }
        try await helperType.prepareForDownload(entry: entry)
    }

    func cancel() {
        task?.cancel()
    }
}
