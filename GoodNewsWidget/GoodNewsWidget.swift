import WidgetKit
import SwiftUI

struct NewsProvider: TimelineProvider {
    private static func cacheDir() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    func placeholder(in context: Context) -> NewsEntry {
        NewsEntry(date: Date(), page: .india, items: DemoData.items(page: .india), updatedAt: Date(), isStale: false, allFailed: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) {
        let engine = RSSEngine(cacheDirectory: Self.cacheDir())
        let page = WidgetState.currentPage()
        if let cached = engine.loadCached() {
            completion(NewsEntry(date: Date(), page: page, items: cached.items.filter { $0.page == page }, updatedAt: cached.updatedAt, isStale: !cached.failedSources.isEmpty, allFailed: false))
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        let engine = RSSEngine(cacheDirectory: Self.cacheDir())
        Task {
            let snapshot = await engine.refresh()
            let page = WidgetState.currentPage()
            let items = snapshot.items.filter { $0.page == page }
            let allFailed = snapshot.failedSources.count == FeedDirectory.all.count && items.isEmpty
            let now = Date()
            let entries = (0..<16).map { i in
                NewsEntry(date: now.addingTimeInterval(TimeInterval(i) * 900), page: page, items: items,
                          updatedAt: snapshot.updatedAt, isStale: !snapshot.failedSources.isEmpty, allFailed: allFailed)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

struct GoodNewsWidgetEntryView: View {
    let entry: NewsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        default: LargeWidgetView(entry: entry)
        }
    }
}

@main
struct GoodNewsWidgetBundle: WidgetBundle {
    var body: some Widget {
        GoodNewsWidget()
    }
}

struct GoodNewsWidget: Widget {
    let kind = "GoodNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsProvider()) { entry in
            GoodNewsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Good News")
        .description("Newspaper headlines from India and the world.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
