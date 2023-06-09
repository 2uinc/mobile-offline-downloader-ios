import SwiftSoup

protocol HTMLSoupHelperProtocol {}

extension HTMLSoupHelperProtocol {
    func addTagIfNeeded(_ tag: String, contents: String, id: String, to document: Document?) throws {
        if try document?.getElementById(id) == nil, let head = document?.head() {
            let tag = """
                <\(tag) id="\(id)">
                    \(contents)
                </\(tag)>
            """
            try head.append(tag)
        }
    }

    func parent(for className: String, from element: Element?) -> Element? {
        guard let parentElement = element?.parent() else { return nil }
        if parentElement.hasClass(className) {
            return parentElement
        } else {
            return parent(for: className, from: parentElement)
        }
    }
}
