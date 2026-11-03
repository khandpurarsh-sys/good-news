import Foundation

final class RSSEngine {
    struct Snapshot: Codable {
        var items: [FeedItem]
        var updatedAt: Date
        var failedSources: [String]
    }

    enum FeedError: Error { case http(Int), parse, transport }

    let cacheURL: URL
    private let stateURL: URL
    private let session: URLSession

    init(cacheDirectory: URL, session: URLSession = .shared) {
        self.cacheURL = cacheDirectory.appendingPathComponent("news-cache.json")
        self.stateURL = cacheDirectory.appendingPathComponent("feed-state.json")
        self.session = session
    }

    func loadCached() -> Snapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    @discardableResult
    func refresh(now: Date = Date()) async -> Snapshot {
        let cached = loadCached()
        var retryState = (try? JSONDecoder().decode([String: Date].self, from: Data(contentsOf: stateURL))) ?? [:]
        var collected: [FeedItem] = []
        var failed: [String] = []
        await withTaskGroup(of: (FeedSpec, Result<[FeedItem], FeedError>).self) { group in
            for spec in FeedDirectory.all {
                if let next = retryState[spec.name], next > now {
                    failed.append(spec.name)
                    continue
                }
                group.addTask { (spec, await self.fetch(spec)) }
            }
            for await (spec, result) in group {
                switch result {
                case .success(let items):
                    collected.append(contentsOf: items)
                    retryState.removeValue(forKey: spec.name)
                case .failure:
                    failed.append(spec.name)
                    retryState[spec.name] = now.addingTimeInterval(600) // 10 min backoff
                }
            }
        }
        // Keep old items from feeds that failed this cycle (B2/B4)
        if let cached {
            let failedNames = Set(failed)
            let keep = cached.items.filter { failedNames.contains($0.source) }
            let freshKeys = Set(collected.map { $0.id })
            collected.append(contentsOf: keep.filter { !freshKeys.contains($0.id) })
        }
        let merged = Self.dedupe(collected)
        let snapshot = Snapshot(items: merged, updatedAt: cached?.updatedAt ?? now, failedSources: failed)
        var final = snapshot
        if !failed.isEmpty, cached != nil {
            final.updatedAt = cached!.updatedAt // "updated" tracks last successful fetch (F6)
        } else {
            final.updatedAt = now
        }
        if let data = try? JSONEncoder().encode(final) { try? data.write(to: cacheURL, options: .atomic) }
        if let data = try? JSONEncoder().encode(retryState) { try? data.write(to: stateURL, options: .atomic) }
        return final
    }

    private func fetch(_ spec: FeedSpec) async -> Result<[FeedItem], FeedError> {
        var request = URLRequest(url: spec.url, timeoutInterval: 10)
        request.setValue("GoodNews/1.0 (personal RSS reader)", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.transport)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return .failure(.http(http.statusCode))
        }
        do {
            let items = try Self.parse(data: data, spec: spec)
            return .success(items)
        } catch {
            return .failure(.parse)
        }
    }

    // MARK: - Parsing

    static func parse(data: Data, spec: FeedSpec) throws -> [FeedItem] {
        let delegate = FeedXMLDelegate(spec: spec)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.failed else { throw FeedError.parse }
        return delegate.items
    }

    static func dedupe(_ items: [FeedItem]) -> [FeedItem] {
        var byKey: [String: FeedItem] = [:]
        var titleIndex: [String: String] = [:]
        let preferred = ["The Hindu", "Times of India", "NDTV", "Indian Express", "BBC News", "Al Jazeera", "The Guardian", "NPR"]
        for item in items {
            let norm = normalizedTitle(item.title)
            let key = titleIndex[norm] ?? item.id
            if let existing = byKey[key] {
                // C3: keep earliest pubDate; on tie prefer earlier source in the preferred order
                let existingRank = preferred.firstIndex(of: existing.source) ?? .max
                let itemRank = preferred.firstIndex(of: item.source) ?? .max
                let existingDate = existing.date ?? .distantFuture
                let itemDate = item.date ?? .distantFuture
                if (itemDate, -itemRank) < (existingDate, -existingRank) {
                    byKey[key] = item
                }
            } else {
                byKey[key] = item
            }
            titleIndex[norm] = key
        }
        return byKey.values.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    static func normalizedTitle(_ title: String) -> String {
        var t = title.lowercased()
        if let range = t.range(of: " - ", options: .backwards) { t = String(t[..<range.lowerBound]) }
        t = t.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
        return t.split(separator: " ").joined(separator: " ")
    }

    static func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        let iso2 = ISO8601DateFormatter()
        if let d = iso2.date(from: raw) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "dd MMM yyyy HH:mm:ss Z", "yyyy-MM-dd HH:mm:ss Z"] {
            f.dateFormat = format
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
}

private final class FeedXMLDelegate: NSObject, XMLParserDelegate {
    let spec: FeedSpec
    var items: [FeedItem] = []
    var failed = false

    private var element = ""
    private var buffer = ""
    private var inItem = false
    private var inContent = false
    private var title = ""
    private var link = ""
    private var summary = ""
    private var dateRaw = ""
    private var guid = ""
    private var seenAny = false

    init(spec: FeedSpec) { self.spec = spec }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        element = name.lowercased()
        buffer = ""
        if element == "item" || element == "entry" {
            inItem = true; seenAny = true
            title = ""; link = ""; summary = ""; dateRaw = ""; guid = ""
        }
        if inItem && element == "link", let href = attributes["href"], link.isEmpty {
            link = href // Atom link href
        }
        if inItem && (element == "content" || element == "description" || element == "summary" || element == "encoded") {
            inContent = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let s = String(data: CDATABlock, encoding: .utf8) else { return }
        buffer += s
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let e = name.lowercased()
        if e == "item" || e == "entry" {
            finishItem()
            inItem = false
            return
        }
        guard inItem else { return }
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "title": if title.isEmpty { title = value }
        case "link": if link.isEmpty, value.hasPrefix("http") { link = value }
        case "guid", "id": if guid.isEmpty { guid = value }
        case "pubdate", "published", "updated", "date": if dateRaw.isEmpty { dateRaw = value }
        case "description", "summary", "encoded", "content":
            if summary.isEmpty { summary = FeedXMLDelegate.stripHTML(value) }
            inContent = false
        default: break
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        failed = true
    }

    private func finishItem() {
        guard !title.isEmpty else { return }
        let base = spec.url
        let url = link.isEmpty ? nil : URL(string: link, relativeTo: base)?.absoluteURL
        let key = !guid.isEmpty ? guid : (url?.absoluteString ?? RSSEngine.normalizedTitle(title))
        items.append(FeedItem(
            id: "\(spec.name)|\(key)",
            title: title,
            link: url,
            summary: summary.isEmpty ? nil : summary,
            date: RSSEngine.parseDate(dateRaw),
            source: spec.name,
            page: spec.page
        ))
    }

    static func stripHTML(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&nbsp;": " "]
        for (k, v) in entities { out = out.replacingOccurrences(of: k, with: v) }
        return out.split(separator: " ").joined(separator: " ")
    }
}
