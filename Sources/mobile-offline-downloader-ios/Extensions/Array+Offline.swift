extension Array where Element == OfflineDownloaderLink {
    mutating func appendDistinct(_ element: Element) {
        if let _ = first(where: { $0.link == element.link }) {
            return
        }
        append(element)
    }
    
    mutating func appendDistinct(_ elements: [Element]) {
        for element in elements {
            appendDistinct(element)
        }
    }
}
