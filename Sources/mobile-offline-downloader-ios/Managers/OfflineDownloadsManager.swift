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
    private var cancellables: [AnyCancellable] = []
    private var sourcePublisher: PassthroughSubject<OfflineDownloadsManagerEvent, Never> = .init()
    lazy public var publisher: AnyPublisher<OfflineDownloadsManagerEvent, Never> =  {
        sourcePublisher
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }()
    
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

    func getEntry(for id: String, type: String) -> OfflineDownloaderEntry? {
        entries.first {
            $0.dataModel.id == id &&
            $0.dataModel.type == type
        }
    }

    public func isDownloaded<T: OfflineDownloadTypeProtocol>(object: T, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        do {
            let dataModel = try object.toOfflineModel()
            let id = dataModel.id + "_" + dataModel.type
            OfflineStorageManager.shared.load(for: id, castingType: OfflineDownloaderEntry.self) { result in
                switch result {
                case .success(let entry):
                    completionHandler(.success(entry.isDownloaded))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
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
                    guard let entry = entry else { return }
                    OfflineStorageManager.shared.save(entry) { result in }
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
