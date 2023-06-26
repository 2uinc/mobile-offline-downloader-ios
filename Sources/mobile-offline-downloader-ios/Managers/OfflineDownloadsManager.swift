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
        if !entry.isDownloaded && activeEntries.count < config.limitOfConcurrentDownloads {
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

    public func pause(entry: OfflineDownloaderEntry) {

    }

    public func cancel(entry: OfflineDownloaderEntry) {

    }

    public func resume(entry: OfflineDownloaderEntry) {
        
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
                completionHandler(.success(entry.isDownloaded))
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
        if let index = entries.firstIndex(where: { $0.dataModel.id == entry.dataModel.id }) {
            let managerEntry = entries[index]
            if let downloader = getDownloader(for: managerEntry) {
                downloader.cancel()

                if let index = downloaders.firstIndex(of: downloader) {
                    downloaders.remove(at: index)
                }
            }
            entries.remove(at: index)
        }
        let path = entry.rootPath(with: config.rootPath)
        try FileManager.default.removeItem(atPath: path)

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
                    let status: OfflineDownloaderStatus = entry.isDownloaded ? .completed : .initialized
                    let progress: Double = entry.isDownloaded ? 1 : 0
                    let eventObject = OfflineDownloadsManagerEventObject(object: object, status: status, progress: progress)
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
        downloader.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink {[weak self, weak entry, weak downloader] status in
                guard let downloader = downloader, let object = self?.object(for: downloader.entry.dataModel) else { return }

                let publisherObject = OfflineDownloadsManagerEventObject(object: object, status: status, progress: downloader.progress.fractionCompleted)
                self?.sourcePublisher.send(.statusChanged(object: publisherObject))
                switch status {
                case .completed:
                    print("publisherObject completed")
                    guard let entry = entry else { return }
                    OfflineStorageManager.shared.save(entry) { result in
                        switch result {
                        case .success:
                            print("✅ Download finished and saved to Realm")
                        case .failure(let error):
                            print("⚠️ Download finished but Realm failed error = \(error)")
                        }
                    }
                default:
                    break
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
