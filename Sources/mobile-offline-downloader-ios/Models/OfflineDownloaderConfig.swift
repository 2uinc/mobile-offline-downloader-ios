import Foundation

public class OfflineDownloaderConfig {
    var shouldCacheCSS: Bool = true
    var rootPath: String = NSTemporaryDirectory()
    var limitOfConcurrentDownloads: Int = 3
}
