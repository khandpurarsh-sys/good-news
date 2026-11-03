import Foundation
import SwiftUI

struct FeedItem: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let link: URL?
    let summary: String?
    let date: Date?
    let source: String
    let page: NewsPage
}

enum NewsPage: String, Codable, CaseIterable {
    case india, global
    var title: String { self == .india ? "INDIA" : "GLOBAL" }
}

struct FeedSpec: Hashable {
    let name: String
    let url: URL
    let page: NewsPage
}

enum FeedDirectory {
    static let all: [FeedSpec] = [
        FeedSpec(name: "The Hindu", url: URL(string: "https://www.thehindu.com/news/national/feeder/default.rss")!, page: .india),
        FeedSpec(name: "Times of India", url: URL(string: "https://timesofindia.indiatimes.com/rssfeeds/-2128936835.cms")!, page: .india),
        FeedSpec(name: "NDTV", url: URL(string: "https://feeds.feedburner.com/ndtvnews-top-stories")!, page: .india),
        FeedSpec(name: "Indian Express", url: URL(string: "https://indianexpress.com/section/india/feed/")!, page: .india),
        FeedSpec(name: "BBC News", url: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!, page: .global),
        FeedSpec(name: "Al Jazeera", url: URL(string: "https://www.aljazeera.com/xml/rss/all.xml")!, page: .global),
        FeedSpec(name: "The Guardian", url: URL(string: "https://www.theguardian.com/world/rss")!, page: .global),
        FeedSpec(name: "NPR", url: URL(string: "https://feeds.npr.org/1001/rss.xml")!, page: .global),
    ]
}

enum NewspaperTheme {
    static func paper(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.09, green: 0.08, blue: 0.06) : Color(red: 0.972, green: 0.953, blue: 0.910)
    }
    static func ink(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.92, green: 0.89, blue: 0.82) : Color(red: 0.11, green: 0.10, blue: 0.075)
    }
    static func secondaryInk(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.62, green: 0.58, blue: 0.50) : Color(red: 0.42, green: 0.39, blue: 0.33)
    }
    static func rule(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.24, green: 0.22, blue: 0.17) : Color(red: 0.79, green: 0.75, blue: 0.66)
    }
    static func mastheadFont(size: CGFloat) -> Font { .system(size: size, weight: .black, design: .serif) }
    static func headlineFont(size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func metaFont(size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .default) }
}

enum DemoData {
    static func items(page: NewsPage) -> [FeedItem] {
        let now = Date()
        let india: [(String, String, Int)] = [
            ("Monsoon advances into central India a week ahead of schedule", "The Hindu", 12),
            ("Parliament passes new digital competition bill after late-night debate", "Times of India", 34),
            ("ISRO completes docking test for upcoming crewed mission", "NDTV", 58),
            ("Supreme Court reserves verdict on states' borrowing powers", "Indian Express", 83),
            ("Railways opens first stretch of dedicated freight corridor in Punjab", "The Hindu", 121),
            ("Heat action plans expand to 250 districts, says disaster agency", "NDTV", 165),
            ("Rupee firms as exporters sell dollars; RBI seen on sidelines", "Indian Express", 190),
        ]
        let global: [(String, String, Int)] = [
            ("UN climate talks open with finance pledges under scrutiny", "BBC News", 15),
            ("Ceasefire talks resume after overnight strikes in coastal region", "Al Jazeera", 40),
            ("Central banks signal diverging paths on rate cuts", "The Guardian", 66),
            ("NASA's lunar station passes first full-power test", "NPR", 95),
            ("EU ministers reach deal on cross-border energy grid funding", "BBC News", 130),
            ("Pacific nations press for stronger shipping emissions rules", "Al Jazeera", 172),
            ("Global wheat prices ease after record harvest estimates", "The Guardian", 205),
        ]
        let rows = page == .india ? india : global
        return rows.map { FeedItem(id: "demo-\($0.2)", title: $0.0, link: URL(string: "https://example.com/a/\($0.2)"), summary: nil, date: now.addingTimeInterval(TimeInterval(-$0.2 * 60)), source: $0.1, page: page) }
    }
}
