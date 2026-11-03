import Foundation
import SwiftUI

@MainActor
final class AppNewsStore: ObservableObject {
    @Published var snapshot: RSSEngine.Snapshot?
    @Published var refreshing = false

    private let engine: RSSEngine = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return RSSEngine(cacheDirectory: dir)
    }()

    var demoMode: Bool { CommandLine.arguments.contains("-demo") }

    func load() async {
        if demoMode { return }
        if snapshot == nil { snapshot = engine.loadCached() }
        refreshing = true
        snapshot = await engine.refresh()
        refreshing = false
    }

    func items(for page: NewsPage) -> [FeedItem] {
        if demoMode { return DemoData.items(page: page) }
        return (snapshot?.items ?? []).filter { $0.page == page }
    }

    var updatedText: String {
        if demoMode { return "Updated just now" }
        guard let date = snapshot?.updatedAt else { return "Not updated yet" }
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes)m ago" }
        return "Updated \(minutes / 60)h \(minutes % 60)m ago"
    }
}
