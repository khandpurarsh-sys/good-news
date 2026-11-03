import WidgetKit
import SwiftUI

struct NewsEntry: TimelineEntry {
    let date: Date
    let page: NewsPage
    let items: [FeedItem]
    let updatedAt: Date
    let isStale: Bool
    let allFailed: Bool
}

enum WidgetState {
    private static let key = "widgetPage"
    static func currentPage(defaults: UserDefaults = .standard) -> NewsPage {
        NewsPage(rawValue: defaults.string(forKey: key) ?? "") ?? .india
    }
    static func setPage(_ page: NewsPage, defaults: UserDefaults = .standard) {
        defaults.set(page.rawValue, forKey: key)
    }
}

struct TogglePageIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch India / Global"
    static var description = IntentDescription("Switches the widget between the India and Global pages.")

    func perform() async throws -> some IntentResult {
        let current = WidgetState.currentPage()
        WidgetState.setPage(current == .india ? .global : .india)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh headlines"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SetPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Show page"

    @Parameter(title: "Page")
    var page: String

    init() { self.page = NewsPage.india.rawValue }
    init(page: NewsPage) { self.page = page.rawValue }

    func perform() async throws -> some IntentResult {
        WidgetState.setPage(NewsPage(rawValue: page) ?? .india)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
