import Foundation

public class OfflineDownloadsManager {
    public static var shared: OfflineDownloadsManager = .init()

    var config: OfflineDownloaderConfig = OfflineDownloaderConfig()

    var entries: [OfflineDownloaderEntry] = []
    var activeEntries: [OfflineDownloaderEntry] {
        []
    }

    var completedEntries: [OfflineDownloaderEntry] {
        []
    }

    var pausedEntries: [OfflineDownloaderEntry] {
        []
    }

    var downloaders: [OfflineEntryDownloader] = []

    public func setConfig(_ config: OfflineDownloaderConfig) {
        self.config = config
    }

    public func addAndStart(entry: OfflineDownloaderEntry) {
        guard getEntry(for: entry.dataModel.id, type: entry.dataModel.type) == nil else { return }
        entries.append(entry)
        start(entry: entry)
    }

    public func remove(entry: OfflineDownloaderEntry) {

    }

    public func start(entry: OfflineDownloaderEntry) {
        if entry.status.canStart && activeEntries.count < config.limitOfConcurrentDownloads {
            if let downloader = getDownloader(for: entry) {
                downloader.start()
            } else {
                let downloader = OfflineEntryDownloader(entry: entry, config: config)
                downloaders.append(downloader)
                downloader.start()
            }
        }
    }

    public func pause(entry: OfflineDownloaderEntry) {

    }

    public func cancel(entry: OfflineDownloaderEntry) {

    }

    func getEntry(for id: String, type: String) -> OfflineDownloaderEntry? {
        entries.first {
            $0.dataModel.id == id &&
            $0.dataModel.type == type
        }
    }

    func getDownloader(for entry: OfflineDownloaderEntry) -> OfflineEntryDownloader? {
        downloaders.first {
            $0.entry.dataModel.id == entry.dataModel.id &&
            $0.entry.dataModel.type == entry.dataModel.type
        }
    }
}
