import AppKit
import Foundation

extension PlanWalkthrough {
    func fileTagNames(_ url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []
    }

    func readPasteboardString() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    func firstPort(in text: String) -> Int? {
        guard let match = text.range(of: #"(?<![\d.])\d{4,5}(?![\d.])"#, options: .regularExpression) else {
            return nil
        }
        return Int(text[match])
    }

    func httpGet(_ urlString: String, timeout: TimeInterval = 4) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        URLSession.shared.dataTask(with: request) { data, _, _ in
            box.value = data.flatMap { String(data: $0, encoding: .utf8) }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 1)
        return box.value
    }

    private final class ResultBox: @unchecked Sendable {
        var value: String?
    }
}
