import SwiftUI

@main
struct GoodNewsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var store = AppNewsStore()
    @Environment(\.colorScheme) private var scheme

    private var shotMode: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-shot"), args.count > i + 1 else { return nil }
        return args[i + 1]
    }

    var body: some View {
        Group {
            if let mode = shotMode {
                ScreenshotModeView(mode: mode)
            } else {
                FrontPageView(store: store)
            }
        }
        .background(NewspaperTheme.paper(for: scheme).ignoresSafeArea())
    }
}
