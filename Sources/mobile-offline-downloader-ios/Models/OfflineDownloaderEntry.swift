import Foundation

enum OfflineDownloaderStatus {
    case initialized, preparing, paused, active, partialy, completed

    var canResume: Bool {
        return self == .paused
    }

    var canStart: Bool {
        return self == .initialized || self == .paused
    }
}

public class OfflineDownloaderEntry {
    public var dataModel: OfflineStorageDataModel
    var parts: [OfflineDownloaderEntryPart]
    var percent: CGFloat = 0
    var status: OfflineDownloaderStatus {
        // TODO: go throught parts and check status then return part
        return .initialized
    }

    init(dataModel: OfflineStorageDataModel, parts: [OfflineDownloaderEntryPart]) {
        self.dataModel = dataModel
        self.parts = parts
    }

    public func addHtmlPart(_ html: String, baseURL: String?) {
        let part = OfflineDownloaderEntryPart(value: .html(html: html, baseURL: baseURL))
        parts.append(part)
    }

    public func addURLPart(_ link: String) {
        let part = OfflineDownloaderEntryPart(value: .url(link))
        parts.append(part)
    }
}
