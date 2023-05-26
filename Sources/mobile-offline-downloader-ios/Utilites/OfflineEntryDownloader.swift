import Foundation
import Combine

@objc enum OfflineDownloaderStatus: Int {
    case initialized, preparing, paused, active, completed, cancelled

    var canResume: Bool {
        return self == .paused
    }

    var canStart: Bool {
        return self == .initialized || self == .paused
    }
}

class OfflineEntryDownloader: NSObject {
    var config: OfflineDownloaderConfig
    var entry: OfflineDownloaderEntry
    private var task: Task<(), Never>?
    @objc dynamic var progress: Progress = Progress()

    @objc dynamic var status: OfflineDownloaderStatus = .initialized

    init(entry: OfflineDownloaderEntry, config: OfflineDownloaderConfig) {
        self.entry = entry
        self.config = config
    }

    func start() {
        task = Task {
            do {
                status = .preparing
                try await prepare()
                status = .active
                progress.totalUnitCount = Int64(entry.parts.count)
                for part in entry.parts {
                    try await download(part: part)
                }
                entry.isDownloaded = true
                status = .completed
                // TODO: Save to database
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
        
        let downloader = OfflineEntryPartDownloader(part: part, rootPath: rootPath, htmlIndexName: config.indexFileName)
        progress.addChild(downloader.progress, withPendingUnitCount: 1)
        try await downloader.download()
    }

    private func prepare() async throws {
        guard let helperType = config.downloadTypes.first(where: { $0.canDownload(entry: entry) }) else { return }
        try await helperType.prepareForDownload(entry: entry)
    }

    func cancel() {
        task?.cancel()
        status = .cancelled
    }
    
    func pause() {
        task?.cancel()
        status = .paused
    }
    
    func resume() {
        start()
    }
}
