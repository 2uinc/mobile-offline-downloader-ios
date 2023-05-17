# mobile-offline-downloader-ios

`mobile-offline-downloader-ios` is a pure Swift library that allow you to download html contents and resume it without internet connection.

## Installation

### Swift Package Manager
`mobile-offline-downloader-ios` is also available through [Swift Package Manager](https://github.com/apple/swift-package-manager). 
To install it, simply add the dependency to your Package.Swift file:

```swift
...
dependencies: [
    .package(url: "https://github.com/2uinc/mobile-offline-downloader-ios.git", from: "0.0.0"),
],
targets: [
    .target( name: "YourTarget", dependencies: ["mobile-offline-downloader-ios"]),
]
...
```

## Usage

### Implement storage and downloaders protocol

To use package you need to implement protocols for each type what you want to store and resume in offline. 

First you need to implement `OfflineStorageDataProtocol` to give `mobile-offline-downloader-ios` package availability to save and resume data.

```swift
extension CustomType: OfflineStorageDataProtocol {
  public static func fromOfflineModel(_ model: OfflineStorageDataModel) -> CustomType? {
    // use this function to convert stored data to your type
  }
  
  public func toOfflineModel() -> OfflineStorageDataModel {
    // use this function to convert your type to OfflineStorageDataModel
  }
}
```

Then you need to implement `OfflineDownloadHelperProtocol` to make package to know how to prepare data

```swift
extension CustomType: OfflineDownloadHelperProtocol {
  public static func prepareForDownload(entry: OfflineDownloaderEntry) async throws {
    // use this funtion to make calls to API and prepare `[OfflineDownloaderEntryPart]`
    ...
    // to add html part use `addHtmlPart` method
    entry?.addHtmlPart(fullHTML, baseURL: page?.html_url.absoluteString)
    ...
    // to add a link to single file use `addURLPart`
    entry?.addURLPart("http://google.com/somefile.pdf")
  }
}
```

You also can configure storage and downloaders with `OfflineStorageConfig` and `OfflineDownloaderConfig` object

```swift
let downloaderConfig = OfflineDownloaderConfig()
downloaderConfig.shouldCacheCSS = true
downloaderConfig.limitOfConcurrentDownloads = 3
OfflineDownloadsManager.shared.setConfig(downloaderConfig)
```

Then you are ready to start download

```swift
let objectToSave = CustomType()
let data = OfflineStorageManager.shared.dataModel(for: objectToSave)
let entry = OfflineDownloaderEntry(dataModel: data, parts: [])
OfflineDownloadsManager.shared.addAndStart(entry: entry)
```
