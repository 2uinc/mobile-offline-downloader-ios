import Foundation
import Combine

@objc public enum OfflineDownloaderStatus: Int {
    case initialized, preparing, paused, active, completed, cancelled, removed, failed

    var canResume: Bool {
        return self == .paused
    }

    var canStart: Bool {
        return self == .initialized || self == .paused || self == .failed
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
                entry.updateTimestamp()
                if entry.parts.isEmpty {
                    // skip if data prepared already
                    status = .preparing
                    try await prepare()
                }
                status = .active
                progress.totalUnitCount = Int64(entry.parts.count)
                for part in entry.parts {
                    try await download(part: part)
                }
                entry.updateTimestamp()
                status = .completed
                try await entry.saveToDB()
            } catch {
                if !error.isCancelled {
                    entry.errors.append(error)
                    print("⚠️ Download of entry = \(entry.dataModel.id) failed with error: \(error.localizedDescription)")
                    status = .failed
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
        guard let helperType = config.downloadTypes.first(where: { $0.canDownload(entry: entry) })
        else { throw OfflineEntryDownloaderError.unsupported(object: entry) }
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
}

extension OfflineEntryDownloader {
    enum OfflineEntryDownloaderError: Error, LocalizedError {
        case unsupported(object: OfflineDownloaderEntry)
        
        var errorDescription: String? {
            switch self {
            case .unsupported(let entry):
                return "This entry is not supported \(entry)"
            }
        }
    }
}
