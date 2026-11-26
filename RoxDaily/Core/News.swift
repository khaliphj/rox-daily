import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct NewsItem: Identifiable, Equatable, Codable {
    var id: String { link }
    let title: String
    let source: String
    let link: String
    let date: Date?
}

enum NewsTopic: String, CaseIterable, Identifiable {
    case local, events, workouts, world
    var id: String { rawValue }

    func title(city: String) -> String {
        switch self {
        case .local: return city
        case .events: return "Events"
        case .workouts: return "Workouts"
        case .world: return "All News"
        }
    }

    func query(city: String) -> String {
        switch self {
        case .local: return "HYROX \(city)"
        case .events: return "HYROX (\(city) OR Georgia) (race OR event OR tickets OR registration)"
        case .workouts: return "HYROX (workout OR training OR \"training plan\")"
        case .world: return "HYROX"
        }
    }

    func feeds(city: String) -> [URL] {
        let q = query(city: city)
        var google = URLComponents(string: "https://news.google.com/rss/search")!
        google.queryItems = [
            URLQueryItem(name: "q", value: q + " when:60d"),
            URLQueryItem(name: "hl", value: "en-US"), URLQueryItem(name: "gl", value: "US"), URLQueryItem(name: "ceid", value: "US:en")
        ]
        var bing = URLComponents(string: "https://www.bing.com/news/search")!
        bing.queryItems = [URLQueryItem(name: "q", value: q), URLQueryItem(name: "format", value: "rss")]
        return [google.url, bing.url].compactMap { $0 }
    }
}

/// Minimal RSS 2.0 reader: title, link, pubDate and source of each item.
final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var inItem = false
    private var text = ""
    private var title = "", link = "", pub = "", source = ""

    static func parse(_ data: Data) -> [NewsItem] {
        let delegate = RSSParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.items
    }

    private static let dateFormats = ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ"]

    static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if name == "item" { inItem = true; title = ""; link = ""; pub = ""; source = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        text += String(data: block, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard inItem else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name.lowercased() {
        case "title": title = value
        case "link": link = value
        case "pubdate": pub = value
        case "source", "news:source": source = value
        case "item":
            inItem = false
            var headline = title
            // Google News appends " - Publisher" to every headline.
            if !source.isEmpty, headline.hasSuffix(" - " + source) {
                headline = String(headline.dropLast(source.count + 3))
            }
            if !headline.isEmpty, link.hasPrefix("http") {
                items.append(NewsItem(title: headline, source: source, link: link, date: RSSParser.date(pub)))
            }
        default: break
        }
    }
}

enum NewsService {
    /// Tries each feed in turn and returns the first that yields stories, newest first.
    static func fetch(_ topic: NewsTopic, city: String) async throws -> [NewsItem] {
        var lastError: Error = URLError(.badServerResponse)
        for url in topic.feeds(city: city) {
            do {
                var request = URLRequest(url: url, timeoutInterval: 15)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
                let (data, _) = try await URLSession.shared.data(for: request)
                var seen = Set<String>()
                let items = RSSParser.parse(data)
                    .filter { $0.title.range(of: "hyrox", options: .caseInsensitive) != nil }
                    .filter { seen.insert($0.link).inserted }
                if !items.isEmpty {
                    let newest = items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                    guard topic == .local else { return Array(newest.prefix(40)) }
                    // Stories that name the city or state lead the local tab.
                    let isLocal: (NewsItem) -> Bool = { item in
                        [city, "Georgia"].contains { item.title.range(of: $0, options: .caseInsensitive) != nil }
                    }
                    return Array((newest.filter(isLocal) + newest.filter { !isLocal($0) }).prefix(40))
                }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
