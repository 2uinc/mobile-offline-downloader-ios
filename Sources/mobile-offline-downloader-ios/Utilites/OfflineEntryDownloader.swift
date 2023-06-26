import Foundation
import Combine

@objc public enum OfflineDownloaderStatus: Int {
    case initialized, preparing, paused, active, completed, cancelled, removed, failed

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
    lazy var statusPublisher: CurrentValueSubject<OfflineDownloaderStatus, Never> = {
        CurrentValueSubject<OfflineDownloaderStatus, Never>(status)
    }()
    
    var status: OfflineDownloaderStatus {
        get {
            entry.status
        }
        set {
            entry.status = newValue
            statusPublisher.send(newValue)
        }
    }
    
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
                try await saveToDB()
                status = .completed
            } catch {
                // TODO: save error
                print("⚠️ Download of entry = \(entry.dataModel.id) failed with error: \(error.localizedDescription)")
                status = .failed
            }
        }
    }
    
    private func saveToDB() async throws {
        try await withCheckedThrowingContinuation { continuation in
            OfflineStorageManager.shared.save(entry) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func download(part: OfflineDownloaderEntryPart) async throws {
        var rootPath = entry.rootPath(with: config.rootPath)
        if let index = entry.index(for: part) {
            rootPath += "/\(index)"
        }
        
        let downloader = OfflineEntryPartDownloader(part: part, rootPath: rootPath, htmlIndexName: config.indexFileName)
        progress.addChild(downloader.progress, withPendingUnitCount: 1)
        try await downloader.download()
    }

    @MainActor
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
