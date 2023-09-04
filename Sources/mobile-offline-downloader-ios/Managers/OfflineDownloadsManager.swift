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
    public var isSupported: Bool
}

public enum OfflineDownloadsQueueEvent {
    case completed(success: Bool)
    case entriesStartLoad
    case entriesLoaded(error: Error?)
}

public class OfflineDownloadsManager {
    public static var shared: OfflineDownloadsManager = .init()

    public private(set) var config: OfflineDownloaderConfig = OfflineDownloaderConfig() {
        didSet {
            updateFolder()
        }
    }

    var entries: [OfflineDownloaderEntry] = []
    public var isLoading: Bool = false
    public var activeEntries: [OfflineDownloaderEntry] {
        entries
            .filter {
                (
                    $0.status == .active ||
                    $0.status == .preparing ||
                    (
                        $0.status == .paused && $0.isForcePaused
                    )
                ) && !$0.isUnsupported
            }
    }

    public var completedEntries: [OfflineDownloaderEntry] {
        entries
            .filter { ($0.status == .completed || $0.status == .partiallyDownloaded) && !$0.isUnsupported }
    }

    public var waitingEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .initialized && !$0.isUnsupported }
    }
    
    public var pausedEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .paused && !$0.isUnsupported }
    }
    
    public var failedEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.status == .failed && !$0.isUnsupported }
    }

    public var unsupportedEntries: [OfflineDownloaderEntry] {
        entries
            .filter { $0.isUnsupported }
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
    private var sourceQueuePublisher: PassthroughSubject<OfflineDownloadsQueueEvent, Never> = .init()
    lazy public var queuePublisher: AnyPublisher<OfflineDownloadsQueueEvent, Never> =  {
        sourceQueuePublisher
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }()

    init() {
        updateFolder()
        loadEntries()
    }

    private func loadEntries() {
        isLoading = true
        sourceQueuePublisher.send(.entriesStartLoad)
        OfflineStorageManager.shared.loadAll(of: OfflineDownloaderEntry.self) { result in
            self.isLoading = false
            switch result {
            case .success(let entries):
                self.entries = entries.sorted(by: {$0.createdDate < $1.createdDate})
                for entry in self.activeEntries + self.waitingEntries {
                    self.start(entry: entry)
                }
                self.sourceQueuePublisher.send(.entriesLoaded(error: nil))
            case .failure(let error):
                self.sourceQueuePublisher.send(.entriesLoaded(error: error))
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

    public func start(object: OfflineDownloadTypeProtocol, userInfo: String? = nil) throws {
        let entry = try object.downloaderEntry()
        entry.userInfo = userInfo
        if getQueuedEntry(for: entry) == nil {
            entries.append(entry)
            entry.saveToDB(completion: {_ in })
        }
        start(entry: entry)
    }
    
    private func sendStatusEvent(for entry: OfflineDownloaderEntry, progress: CGFloat = 0) {
        guard let object = object(for: entry.dataModel) else { return }
        let publisherObject = OfflineDownloadsManagerEventObject(
            object:  object,
            status: entry.status,
            progress: progress,
            isSupported: !entry.isUnsupported
        )
        sourcePublisher.send(.statusChanged(object: publisherObject))
    }

    private func start(entry: OfflineDownloaderEntry) {
        guard let entry = getQueuedEntry(for: entry) else { return }
        if entry.status != .completed || entry.status != .partiallyDownloaded {
            if entry.status != .initialized {
                entry.status = .initialized
            }
            
            sendStatusEvent(for: entry)

            if activeEntries.count < config.limitOfConcurrentDownloads {
                let downloader = getDownloader(for: entry) ?? createDownloader(for: entry)
                if downloader.status.canStart {
                    downloader.start()
                }
            }
        }
    }
    
    private func startNext(latestStatus: OfflineDownloaderStatus) {
        guard let entry = waitingEntries.first else {
            if activeEntries.isEmpty {
                if !failedEntries.filter({ !$0.errors.isEmpty }).isEmpty {

                    sourceQueuePublisher.send(.completed(success: false))

                    failedEntries.forEach {
                        $0.errors = []
                    }
                } else if latestStatus == .completed || latestStatus == .partiallyDownloaded {
                    sourceQueuePublisher.send(.completed(success: true))
                }
            }
            return
        }
        start(entry: entry)
    }

    public func pause(object: OfflineDownloadTypeProtocol) throws {
        let entry = try object.downloaderEntry()
        pause(entry: entry)
    }

    public func pause(entry: OfflineDownloaderEntry) {
        if let downloader = getDownloader(for: entry) {
            downloader.pause()
        } else if let entry = getQueuedEntry(for: entry) {
            entry.status = .paused
            sendStatusEvent(for: entry)
        }
    }

    public func cancel(object: OfflineDownloadTypeProtocol) throws {
        let entry = try object.downloaderEntry()
        cancel(entry: entry)
    }

    public func cancel(entry: OfflineDownloaderEntry) {
        stopLoading(entry: entry)
        removeFromQueue(entry: entry)
    }

    public func deleteDownloadingEntries() throws {
        try entries.filter {
            switch $0.status {
            case .initialized, .active, .preparing, .paused, .failed, .cancelled:
                return true
            default:
                return false
            }
        }.forEach {
            try delete(entry: $0)
        }
    }

    public func resume(entry: OfflineDownloaderEntry) {
        start(entry: entry)
    }
    
    public func resume(object: OfflineDownloadTypeProtocol) throws {
        let entry = try object.downloaderEntry()
        resume(entry: entry)
    }
    
    func getQueuedEntry(for entry: OfflineDownloaderEntry) -> OfflineDownloaderEntry? {
        getEntry(for: entry.dataModel)
    }
    
    func getEntry(for dataModel: OfflineStorageDataModel) -> OfflineDownloaderEntry? {
        getEntry(for: dataModel.id, type: dataModel.type)
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
                completionHandler(.success(entry.status == .completed || entry.status == .partiallyDownloaded))
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
        removeFromStorage(entry: entry)
        try removeLocalFiles(for: entry)
        startNext(latestStatus: .removed)
    }

    public func deleteCompletedEntries(comletion: @escaping () -> Void) throws {
        let group = DispatchGroup()
        try completedEntries.forEach { entry in
            try removeLocalFiles(for: entry)
            removeFromQueue(entry: entry)
            group.enter()
            removeFromStorage(entry: entry) {
                group.leave()
            }
        }
        group.notify(queue: .main) {
            comletion()
        }
    }

    private func removeFromStorage(
        entry: OfflineDownloaderEntry,
        comletion: (() -> Void)? = nil
    ) {
        OfflineStorageManager.shared.delete(entry) {[weak self] result in
            if case .success = result {
                entry.status = .removed
                self?.sendStatusEvent(for: entry)
                comletion?()
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
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
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
            if let entry = getQueuedEntry(for: entry) {
                if let downloader = getDownloader(for: entry) {
                    let progress = downloader.progress.fractionCompleted
                    let eventObject = OfflineDownloadsManagerEventObject(object: object, status: downloader.status, progress: progress, isSupported: !entry.isUnsupported)
                    completionBlock(.success(eventObject))
                } else {
                    let progress: Double = entry.status == .completed || entry.status == .partiallyDownloaded ? 1 : 0
                    let eventObject = OfflineDownloadsManagerEventObject(object: object, status: entry.status, progress: progress, isSupported: !entry.isUnsupported)
                    completionBlock(.success(eventObject))
                }
                return
            }

            savedEntry(for: object) { result in
                switch result {
                case .success(let entry):
                    let progress: Double = entry.status == .completed || entry.status == .partiallyDownloaded ? 1 : 0
                    let eventObject = OfflineDownloadsManagerEventObject(object: object, status: entry.status, progress: progress, isSupported: !entry.isUnsupported)
                    completionBlock(.success(eventObject))
                case .failure(let error):
                    completionBlock(.failure(error))
                }
            }
        } catch {
            completionBlock(.failure(error))
        }
    }
    
    public func canDownload(object: OfflineDownloadTypeProtocol) -> Bool {
        if let entry = try? object.downloaderEntry() {
            let type = type(of: object)
            return type.canDownload(entry: entry)
        }
        return false
    }
    
    func createDownloader(for entry: OfflineDownloaderEntry) -> OfflineEntryDownloader {
        let downloader = OfflineEntryDownloader(entry: entry, config: config)
        downloaders.append(downloader)
        downloader.publisher(for: \.progress.fractionCompleted)
            .receive(on: DispatchQueue.main)
            .sink {[weak self, weak downloader] fractionCompleted in
                guard let downloader = downloader, let object = self?.object(for: downloader.entry.dataModel) else { return }
                let publisherObject = OfflineDownloadsManagerEventObject(object: object, status: downloader.status, progress: downloader.progress.fractionCompleted, isSupported: !downloader.entry.isUnsupported)
                self?.sourcePublisher.send(.progressChanged(object: publisherObject))
            }
            .store(in: &cancellables)
        downloader.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink {[weak self, weak downloader] status in
                guard let downloader = downloader else { return }
                
                self?.sendStatusEvent(for: downloader.entry, progress: downloader.progress.fractionCompleted)
                
                if status == .completed || status == .failed || status == .cancelled || status == .paused || status == .partiallyDownloaded {
                    self?.removeDownloader(for: downloader.entry)
                    self?.startNext(latestStatus: status)
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
    
    // MARK: All queue functions
    public func pauseAllActive() {
        activeEntries.forEach {
            $0.isForcePaused = true
            pause(entry: $0)
        }
    }
    
    public func resumeAllActive() {
        pausedEntries.forEach {
            if $0.isForcePaused {
                $0.isForcePaused = false
                start(entry: $0)
            }
        }
    }
}
