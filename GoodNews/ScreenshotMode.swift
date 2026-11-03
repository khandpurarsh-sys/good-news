import SwiftUI
import WidgetKit

// Renders app and widget surfaces deterministically for CI screenshots (-demo data).
struct ScreenshotModeView: View {
    let mode: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch mode {
        case "widget-small":
            WidgetFrame(size: CGSize(width: 158, height: 158)) {
                SmallWidgetView(entry: Self.entry).environment(\.colorScheme, scheme)
            }
        case "widget-medium":
            WidgetFrame(size: CGSize(width: 338, height: 158)) {
                MediumWidgetView(entry: Self.entry).environment(\.colorScheme, scheme)
            }
        case "widget-large":
            WidgetFrame(size: CGSize(width: 338, height: 354)) {
                LargeWidgetView(entry: Self.entry).environment(\.colorScheme, scheme)
            }
        default:
            FrontPageView(store: AppNewsStore())
        }
    }

    static var entry: NewsEntry {
        NewsEntry(date: Date(), page: .india, items: DemoData.items(page: .india),
                  updatedAt: Date(), isStale: false, allFailed: false)
    }
}

struct WidgetFrame<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(white: scheme == .dark ? 0.05 : 0.93).ignoresSafeArea()
            content
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(radius: 8)
        }
    }
}
