import XCTest
@testable import GoodNews

final class RSSEngineTests: XCTestCase {

    private let indiaSpec = FeedSpec(name: "The Hindu", url: URL(string: "https://example.com/base/")!, page: .india)
    private let globalSpec = FeedSpec(name: "BBC News", url: URL(string: "https://example.org/base/")!, page: .global)

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "xml"), "missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    // A1: valid RSS 2.0 - every item parsed, nothing dropped
    func testF1ValidRSS() throws {
        let items = try RSSEngine.parse(data: fixture("F1"), spec: indiaSpec)
        XCTAssertEqual(items.count, 5)
        XCTAssertTrue(items.allSatisfy { !$0.title.isEmpty && $0.link != nil && $0.date != nil })
        XCTAssertEqual(items.first?.source, "The Hindu")
        XCTAssertEqual(items.first?.page, .india)
    }

    // A2: Atom feed parses into the same item model
    func testF2Atom() throws {
        let items = try RSSEngine.parse(data: fixture("F2"), spec: globalSpec)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { !$0.title.isEmpty && $0.link != nil })
    }

    // A3: CDATA and entities render as literal text
    func testF3Entities() throws {
        let items = try RSSEngine.parse(data: fixture("F3"), spec: indiaSpec)
        XCTAssertFalse(items.isEmpty)
        for item in items {
            XCTAssertFalse(item.title.contains("&amp;"), "entity leakage in title")
            XCTAssertFalse(item.title.contains("<![CDATA"), "CDATA marker in title")
            if let s = item.summary {
                XCTAssertFalse(s.contains("&amp;"))
                XCTAssertFalse(s.contains("<"))
            }
        }
    }

    // A4: pubDate variants - missing/invalid kept, no crash, no epoch dates
    func testF4DateVariants() throws {
        let items = try RSSEngine.parse(data: fixture("F4"), spec: indiaSpec)
        XCTAssertFalse(items.isEmpty)
        for item in items {
            if let d = item.date {
                XCTAssertGreaterThan(d.timeIntervalSince1970, 1_000_000_000, "epoch-1970 style date leaked")
            }
        }
    }

    // A5/C1/C2: identity fallbacks and within-feed duplicates
    func testF5IdentityAndDupes() throws {
        let items = try RSSEngine.parse(data: fixture("F5"), spec: indiaSpec)
        XCTAssertFalse(items.isEmpty)
        let deduped = RSSEngine.dedupe(items)
        let ids = deduped.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate rows after dedupe")
    }

    // B1: empty channel parses to zero items, no crash
    func testF6EmptyFeed() throws {
        let items = try RSSEngine.parse(data: fixture("F6"), spec: indiaSpec)
        XCTAssertEqual(items.count, 0)
    }

    // A7: long title stays intact (layout ellipsizes; parser keeps full text)
    func testF7LongTitle() throws {
        let items = try RSSEngine.parse(data: fixture("F7"), spec: indiaSpec)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains { $0.title.count > 100 })
    }

    // A9: malformed XML throws, caller marks the feed failed
    func testF8Malformed() throws {
        XCTAssertThrowsError(try RSSEngine.parse(data: fixture("F8"), spec: indiaSpec))
    }

    // A8: unicode content survives (Devanagari + emoji)
    func testF9Unicode() throws {
        let items = try RSSEngine.parse(data: fixture("F9"), spec: indiaSpec)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains { $0.title.range(of: #"[\p{Devanagari}]"#, options: .regularExpression) != nil || $0.summary?.range(of: #"[\p{Devanagari}]"#, options: .regularExpression) != nil })
    }

    // C3: cross-feed near-duplicate wire story collapses to one, earliest date + preferred source
    func testF10CrossFeedDedupe() throws {
        let a = try RSSEngine.parse(data: fixture("F10a"), spec: FeedSpec(name: "Times of India", url: URL(string: "https://example-a.net/")!, page: .india))
        let b = try RSSEngine.parse(data: fixture("F10b"), spec: FeedSpec(name: "The Hindu", url: URL(string: "https://example-b.net/")!, page: .india))
        let merged = RSSEngine.dedupe(a + b)
        XCTAssertEqual(merged.count, 1, "wire story should dedupe across feeds, got \(merged.map { $0.title })")
        let kept = try XCTUnwrap(merged.first)
        let dates = (a + b).compactMap { $0.date }
        XCTAssertEqual(kept.date, dates.min())
    }

    // C4: same link with changed title updates in place, no duplicate
    func testUpdateInPlace() {
        let d1 = Date(timeIntervalSince1970: 1_700_000_000)
        let d2 = Date(timeIntervalSince1970: 1_700_003_600)
        let old = FeedItem(id: "The Hindu|x", title: "Old headline", link: URL(string: "https://example.com/a")!, summary: nil, date: d1, source: "The Hindu", page: .india)
        let new = FeedItem(id: "The Hindu|x", title: "Updated headline", link: URL(string: "https://example.com/a")!, summary: nil, date: d2, source: "The Hindu", page: .india)
        let merged = RSSEngine.dedupe([old, new])
        XCTAssertEqual(merged.count, 1)
    }

    // A12: relative links resolve against the feed base
    func testRelativeLinkResolution() throws {
        let xml = """
        <?xml version="1.0"?><rss version="2.0"><channel><title>t</title>
        <item><title>Relative story</title><link>/news/123</link><guid>g1</guid></item>
        </channel></rss>
        """.data(using: .utf8)!
        let items = try RSSEngine.parse(data: xml, spec: FeedSpec(name: "S", url: URL(string: "https://host.example/section/feed.xml")!, page: .india))
        XCTAssertEqual(items.first?.link?.absoluteString, "https://host.example/news/123")
    }

    // Date parser coverage
    func testDateParsing() {
        XCTAssertNotNil(RSSEngine.parseDate("Mon, 02 Nov 2026 09:15:00 +0530"))
        XCTAssertNotNil(RSSEngine.parseDate("Mon, 02 Nov 2026 09:15:00 GMT"))
        XCTAssertNotNil(RSSEngine.parseDate("2026-11-02T06:00:00Z"))
        XCTAssertNil(RSSEngine.parseDate("not a date"))
        XCTAssertNil(RSSEngine.parseDate(nil))
    }
}
