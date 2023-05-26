import Foundation

class OfflineLinkDownloader {
    var progress: Progress = Progress(totalUnitCount: 1)
    func download(urlString: String, toFolder folder: String) async throws -> URL {
        progress.completedUnitCount = 0
        if Task.isCancelled { throw URLError(.cancelled) }

        guard let url = URL(string: urlString) else {
            throw OfflineLinkDownloaderError.wrongURL(url: urlString)
        }

        let request = request(for: url)
        
        do {
            let (destinationURL, response) = try await download(with: request)
            let newURL = self.destinationURL(for: url, with: response, in: folder)

            try FileManager.default.createDirectoryAt(path: newURL.path)
            try FileManager.default.moveItem(at: destinationURL, to: newURL)
            return newURL
        } catch {
            throw OfflineLinkDownloaderError.cantDownloadFile(url: url.absoluteString, error: error)
        }
    }
    
    func data(urlString: String) async throws -> Data {
        progress.completedUnitCount = 0
        if Task.isCancelled { throw URLError(.cancelled) }

        guard let url = URL(string: urlString) else {
            throw OfflineLinkDownloaderError.wrongURL(url: urlString)
        }

        let request = request(for: url)
        
        do {
            let (data, _) = try await data(with: request)
            return data
        } catch {
            throw OfflineLinkDownloaderError.cantDownloadFile(url: url.absoluteString, error: error)
        }
    }
    
    func contents(urlString: String) async throws -> String {
        progress.completedUnitCount = 0
        if Task.isCancelled { throw URLError(.cancelled) }

        let data = try await data(urlString: urlString)
        if let contents = String(data: data, encoding: .utf8) {
            return contents
        } else {
            throw OfflineLinkDownloaderError.cantConvertData
        }
    }
    
    private func request(for url: URL) -> URLRequest {
        
        let request = URLRequest(url: url)
        // TODO: ask config for addition headers for url (Referer and etc.)
        return request
    }

    private func path(for url: URL, with response: URLResponse) -> String {
        let path = url.path
        if let last = path.components(separatedBy: "/").last,
           last.contains(".") {
            if response.mimeType?.contains("mp4") == true {
                let nameComponents = last.components(separatedBy: ".")
                return path + "/" + nameComponents[0] + ".mp4"
            }
            if response.mimeType?.contains("audio/mpeg") == true {
                let nameComponents = last.components(separatedBy: ".")
                return path + "/" + nameComponents[0] + ".mp3"
            }
            if response.mimeType?.contains("audio/x-wav") == true {
                let nameComponents = last.components(separatedBy: ".")
                return path + "/" + nameComponents[0] + ".wav"
            }
            return path
        } else if let name = response.suggestedFilename {
            return path + "/" + name
        } else {
            return path + "/" + "\(Date().timeIntervalSince1970).tmp"
        }
    }

    private func alterFilePath(_ filePath: String) -> String {
        var components = filePath.components(separatedBy: "/")
        if let fileName = components.last {
            var fileNameComponents = fileName.components(separatedBy: ".")
            if let name = fileNameComponents.first {
                let newName = name + "\(Date().timeIntervalSince1970)"
                fileNameComponents[0] = newName
            }
            let newName = fileNameComponents.joined(separator: ".")
            components[components.count - 1] = newName
        }
        return components.joined(separator: "/")
    }

    private func destinationURL(for url: URL, with response: URLResponse, in folder: String) -> URL {
        let filePath = path(for: url, with: response)
        var destinationPath = folder.appendPath(filePath)
        if FileManager.default.fileExists(atPath: destinationPath) {
            destinationPath = alterFilePath(destinationPath)
        }
        return URL(fileURLWithPath: destinationPath)
    }

    private func download(with request: URLRequest) async throws -> (URL, URLResponse) {
        var task: URLSessionDownloadTask?
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                task = URLSession.shared.downloadTask(with: request) { url, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url, let response = response {
                        continuation.resume(returning: (url, response))
                    } else {
                        continuation.resume(throwing: OfflineLinkDownloaderError.unknown)
                    }
                }
                if let taskProgress = task?.progress {
                    progress.addChild(taskProgress, withPendingUnitCount: 1)
                }
                task?.resume()
            }
        } onCancel: { [weak task] in
            task?.cancel()
        }
    }
    
    private func data(with request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, *) {
            return try await URLSession.shared.data(for: request)
        } else {
            var task: URLSessionDataTask?
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let data = data, let response = response {
                            continuation.resume(returning: (data, response))
                        } else {
                            continuation.resume(throwing: OfflineLinkDownloaderError.unknown)
                        }
                    })

                    if let taskProgress = task?.progress {
                        progress.addChild(taskProgress, withPendingUnitCount: 1)
                    }

                    task?.resume()
                }
            } onCancel: { [weak task] in
                task?.cancel()
            }
        }
    }
}

extension OfflineLinkDownloader {
    enum OfflineLinkDownloaderError: Error, LocalizedError {
        case unknown
        case wrongURL(url: String)
        case cantDownloadFile(url: String, error: Error)
        case cantConvertData

        var errorDescription: String? {
            switch self {
            case .unknown:
                return "Unknown error was occured"
            case .wrongURL(let url):
                return "URL = \"\(url)\" is incorrect and couldn't be downloaded."
            case let .cantDownloadFile(url, error):
                return "Can't download file at: \(url), with error : \(error.localizedDescription)"
            case .cantConvertData:
                return "Can't convert data."
            }
        }
    }
}

extension FileManager {
    func createDirectoryAt(path: String) throws {
        var components = path.components(separatedBy: "/")
        let fileManager = FileManager.default
        if components.last?.contains(".") == true {
            components.removeLast()
            let newPath = components.joined(separator: "/")
            try fileManager.createDirectory(atPath: newPath, withIntermediateDirectories: true, attributes: nil)
        } else {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

extension URL {
    var filePath: String {
        if #available(iOS 16.0, *) {
            return path(percentEncoded: false)
        } else {
            return path
        }
    }
}
