import Foundation

public class OfflineDownloaderConfig {
    public var shouldCacheCSS: Bool = true
    public var rootPath: String = NSTemporaryDirectory()
    public var limitOfConcurrentDownloads: Int = 3
    public var downloadTypes: [OfflineDownloadTypeProtocol.Type] = []
    public var indexFileName: String = "index.html"
    
    public init(){}
}
