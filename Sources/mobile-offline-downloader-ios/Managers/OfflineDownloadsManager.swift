import Foundation
import Combine

public enum OfflineDownloadsManagerEvent {
    case statusChanged(object: OfflineDownloadsManagerEventObject)
    case progressChanged(object: OfflineDownloadsManagerEventObject)
}

public struct OfflineDownloadsManagerEventObject {
    public var object: OfflineStorageDataProtocol
    public var status: OfflineDownloaderStatus
    public var progress: Double
}
        
public class OfflineDownloadsManager {
    public static var shared: OfflineDownloadsManager = .init()

    var config: OfflineDownloaderConfig = OfflineDownloaderConfig() {
        didSet {
            updateFolder()
        }
    }

    var entries: [OfflineDownloaderEntry] = []
    public var activeEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .active || $0.status == .preparing }
            .sorted(by: { $0.updatedTimestamp > $1.updatedTimestamp })
    }

    public var completedEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .completed }
    }

    public var waitingEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .paused || $0.status == .initialized}
            .sorted(by: { $0.updatedTimestamp > $1.updatedTimestamp })
    }
    
    public var failedEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .failed }
    }

    var downloaders: [OfflineEntryDownloader] = []
    private var cancellables: [AnyCancellable] = []
    private var sourcePublisher: PassthroughSubject<OfflineDownloadsManagerEvent, Never> = .init()
    lazy public var publisher: AnyPublisher<OfflineDownloadsManagerEvent, Never> =  {
        sourcePublisher
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }()
    
    init() {
        updateFolder()
        loadEntries()
    }
    
    private func loadEntries() {
        OfflineStorageManager.shared.loadAll(of: OfflineDownloaderEntry.self) { result in
            if case .success(let entries) = result {
                self.entries = entries
                // TODO: added event that entries loaded
            } else {
                // TODO: failed state
            }
        }
    }
    
    private func updateFolder() {
        do {
            // exclude from cloud backup
            var cacheURL = config.rootPath.fileURL(isDirectory: true)
            let existingValues = try cacheURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
            if existingValues.isExcludedFromBackup == false || existingValues.isExcludedFromBackup == nil {
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try cacheURL.setResourceValues(resourceValues)
            }
        } catch {
            print("Create module cache directory error: " + error.localizedDescription)
        }
    }
    
    public func setConfig(_ config: OfflineDownloaderConfig) {
        self.config = config
    }

    public func addAndStart(object: OfflineDownloadTypeProtocol, userInfo: String? = nil) throws {
        let entry = try object.downloaderEntry()
        entry.userInfo = userInfo
        guard getEntry(for: entry.dataModel.id, type: entry.dataModel.type) == nil else { return }
        entries.append(entry)
        start(entry: entry)
    }

    private func start(entry: OfflineDownloaderEntry) {
        guard getEntry(for: entry.dataModel.id, type: entry.dataModel.type) != nil else { return }
        if entry.status != .completed && activeEntries.count < config.limitOfConcurrentDownloads {
            if let downloader = getDownloader(for: entry) {
                if downloader.status.canStart {
                    downloader.start()
                }
            } else {
                let downloader = createDownloader(for: entry)
                downloaders.append(downloader)
                downloader.start()
            }
        }
    }
    
    private func startNext() {
        guard let entry = waitingEntries.first else { return }
        start(entry: entry)
    }

    public func pause(object: OfflineDownloadTypeProtocol) throws {
        let entry = try object.downloaderEntry()
        pause(entry: entry)
    }

    public func pause(entry: OfflineDownloaderEntry) {
        guard let downloader = getDownloader(for: entry) else { return }
        downloader.pause()
    }

    public func cancel(object: OfflineDownloadTypeProtocol) throws {
        let entry = try object.downloaderEntry()
        cancel(entry: entry)
    }

    public func cancel(entry: OfflineDownloaderEntry) {
        stopLoading(entry: entry)
        removeFromQueue(entry: entry)
    }

    public func resume(entry: OfflineDownloaderEntry) {
        guard let downloader = getDownloader(for: entry) else { return }
        downloader.resume()
    }
    
    func getEntry(for id: String, type: String) -> OfflineDownloaderEntry? {
        entries.first {
            $0.dataModel.id == id &&
            $0.dataModel.type == type
        }
    }

    public func isDownloaded<T: OfflineDownloadTypeProtocol>(object: T, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        savedEntry(for: object) { result in
            switch result {
            case .success(let entry):
                completionHandler(.success(entry.status == .completed))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    public func delete(object: OfflineDownloadTypeProtocol) throws {
        let entry = try object.downloaderEntry()
        try delete(entry: entry)
    }

    public func delete(entry: OfflineDownloaderEntry) throws {
        cancel(entry: entry)
        try removeLocalFiles(for: entry)
        removeFromStorage(entry: entry)
        startNext()
    }

    private func removeFromStorage(entry: OfflineDownloaderEntry) {
        OfflineStorageManager.shared.delete(entry) {[weak self] result in
            guard let self = self, let object = self.object(for: entry.dataModel) else {
                return
            }
            if case .success = result {
                let publisherObject = OfflineDownloadsManagerEventObject(
                    object:  object,
                    status: .removed,
                    progress: 0
                )
                self.sourcePublisher.send(.statusChanged(object: publisherObject))
            }
        }
    }

    private func removeFromQueue(entry: OfflineDownloaderEntry) {
        // Search entry in queue
        if let index = entries.firstIndex(where: { $0.dataModel.id == entry.dataModel.id }) {

            // remove downloader
            removeDownloader(for: entry)
            
            // remove entry
            entries.remove(at: index)
        }
    }

    private func stopLoading(entry: OfflineDownloaderEntry) {
        guard let downloader = getDownloader(for: entry) else { return }
        downloader.cancel()
    }

    private func removeDownloader(for entry: OfflineDownloaderEntry) {
        guard let downloader = getDownloader(for: entry) else { return }
        if let index = downloaders.firstIndex(of: downloader) {
            downloaders.remove(at: index)
        }
    }

    private func removeLocalFiles(for entry: OfflineDownloaderEntry) throws {
        // clear entry directory
        let path = entry.rootPath(with: config.rootPath)
        try FileManager.default.removeItem(atPath: path)
    }

    public func savedEntry<T: OfflineDownloadTypeProtocol>(for object: T, completionHandler: @escaping(Result<OfflineDownloaderEntry, Error>) -> Void) {
        do {
            let dataModel = try object.toOfflineModel()
            let id = dataModel.id + "_" + dataModel.type
            OfflineStorageManager.shared.load(for: id, castingType: OfflineDownloaderEntry.self) { result in
                completionHandler(result)
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

    public func savedValue(for entry: OfflineDownloaderEntry, pageIndex: Int ) -> OfflineDownloaderSavedValue {
        guard pageIndex < entry.parts.count && pageIndex >= 0 else { return .unknown }
        let part = entry.parts[pageIndex]
        let rootPath = entry.rootPath(with: config.rootPath).appendPath("\(pageIndex)")
        
        switch part.value {
        case .html:
            let indexURL = rootPath.appendPath(config.indexFileName).fileURL()
            let folderURL = rootPath.fileURL(isDirectory: true)
            return .html(indexURL: indexURL, folderURL: folderURL)
        case .url:
            guard let relativePath = part.links.first?.downloadedRelativePath else { return .unknown }
            let url = rootPath.appendPath(relativePath).fileURL()
            return .localURL(url)
        }
    }
    
    public func eventObject(for object: OfflineDownloadTypeProtocol, completionBlock: @escaping (Result<OfflineDownloadsManagerEventObject, Error>) -> Void) {
        do {
            let entry = try object.downloaderEntry()
            if let entry = getEntry(for: entry.dataModel.id, type: entry.dataModel.type),
                let downloader = getDownloader(for: entry){
                let progress = downloader.progress.fractionCompleted
                let eventObject = OfflineDownloadsManagerEventObject(object: object, status: downloader.status, progress: progress)
                completionBlock(.success(eventObject))
                return
            }

            savedEntry(for: object) { result in
                switch result {
                case .success(let entry):
                    let progress: Double = entry.status == .completed ? 1 : 0
                    let eventObject = OfflineDownloadsManagerEventObject(object: object, status: entry.status, progress: progress)
                    completionBlock(.success(eventObject))
                case .failure(let error):
                    completionBlock(.failure(error))
                }
            }
        } catch {
            completionBlock(.failure(error))
        }
    }
    
    func createDownloader(for entry: OfflineDownloaderEntry) -> OfflineEntryDownloader {
        let downloader = OfflineEntryDownloader(entry: entry, config: config)
        
        downloader.publisher(for: \.progress.fractionCompleted)
            .receive(on: DispatchQueue.main)
            .sink {[weak self, weak downloader] fractionCompleted in
                guard let downloader = downloader, let object = self?.object(for: downloader.entry.dataModel) else { return }

                let publisherObject = OfflineDownloadsManagerEventObject(object: object, status: downloader.status, progress: downloader.progress.fractionCompleted)
                self?.sourcePublisher.send(.progressChanged(object: publisherObject))
            }
            .store(in: &cancellables)
        downloader.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink {[weak self, weak downloader] status in
                guard let downloader = downloader, let object = self?.object(for: downloader.entry.dataModel) else { return }

                let publisherObject = OfflineDownloadsManagerEventObject(object: object, status: status, progress: downloader.progress.fractionCompleted)
                self?.sourcePublisher.send(.statusChanged(object: publisherObject))
                
                if status == .completed || status == .failed || status == .cancelled {
                    self?.removeDownloader(for: downloader.entry)
                }
                
                if status == .completed || status == .paused || status == .failed || status == .cancelled {
                    self?.startNext()
                }
            }
            .store(in: &cancellables)
        return downloader
    }
    
    func object(for data: OfflineStorageDataModel) -> OfflineDownloadTypeProtocol? {
        for type in config.downloadTypes {
            if let object = try? type.fromOfflineModel(data) {
                return object
            }
        }
        return nil
    }
    
    func getDownloader(for entry: OfflineDownloaderEntry) -> OfflineEntryDownloader? {
        downloaders.first {
            $0.entry.dataModel.id == entry.dataModel.id &&
            $0.entry.dataModel.type == entry.dataModel.type
        }
    }
}
