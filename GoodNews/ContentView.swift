import SwiftUI
import SafariServices

struct FrontPageView: View {
    @ObservedObject var store: AppNewsStore
    @Environment(\.colorScheme) private var scheme
    @State private var page: NewsPage = .india
    @State private var safariURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MastheadView(page: $page, updatedText: store.updatedText)
                    ArticleList(items: store.items(for: page), scheme: scheme) { url in
                        safariURL = url
                    }
                    FooterAttribution()
                }
            }
            .background(NewspaperTheme.paper(for: scheme))
            .refreshable { await store.load() }
            .task { await store.load() }
            .sheet(item: $safariURL) { url in SafariView(url: url).ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.load() }
                    } label: {
                        Image(systemName: store.refreshing ? "arrow.trianglehead.2.clockwise.rotate.90" : "arrow.clockwise")
                    }
                    .tint(NewspaperTheme.ink(for: scheme))
                    .accessibilityLabel("Refresh headlines")
                }
            }
        }
    }
}

struct MastheadView: View {
    @Binding var page: NewsPage
    @Environment(\.colorScheme) private var scheme
    var updatedText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(NewspaperTheme.metaFont(size: 11))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                .padding(.top, 14)
            Text("GOOD NEWS")
                .font(NewspaperTheme.mastheadFont(size: 42))
                .foregroundStyle(NewspaperTheme.ink(for: scheme))
                .padding(.top, 2)
            HStack(spacing: 12) {
                ForEach(NewsPage.allCases, id: \.self) { p in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { page = p }
                    } label: {
                        Text(p.title)
                            .font(NewspaperTheme.metaFont(size: 13).weight(p == page ? .bold : .medium))
                            .kerning(1.2)
                            .foregroundStyle(p == page ? NewspaperTheme.ink(for: scheme) : NewspaperTheme.secondaryInk(for: scheme))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .overlay(alignment: .bottom) {
                                if p == page {
                                    Rectangle().fill(NewspaperTheme.ink(for: scheme)).frame(height: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(p == page ? .isSelected : [])
                }
            }
            .padding(.top, 8)
            RuleView()
            if !updatedText.isEmpty {
                Text(updatedText)
                    .font(NewspaperTheme.metaFont(size: 10))
                    .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct RuleView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(NewspaperTheme.ink(for: scheme)).frame(height: 2)
            Rectangle().fill(NewspaperTheme.rule(for: scheme)).frame(height: 0.5)
        }
        .padding(.top, 8)
    }
}

struct ArticleList: View {
    let items: [FeedItem]
    let scheme: ColorScheme
    let onOpen: (URL) -> Void

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 12) {
                Text("No headlines yet")
                    .font(NewspaperTheme.headlineFont(size: 17))
                    .foregroundStyle(NewspaperTheme.ink(for: scheme))
                Text("Pull to refresh")
                    .font(NewspaperTheme.metaFont(size: 13))
                    .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button { if let url = item.link { onOpen(url) } } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(NewspaperTheme.headlineFont(size: index == 0 ? 21 : 17))
                                .foregroundStyle(NewspaperTheme.ink(for: scheme))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                Text(item.source.uppercased())
                                    .font(NewspaperTheme.metaFont(size: 10).weight(.semibold))
                                    .kerning(1)
                                if let date = item.date {
                                    Text("·")
                                    Text(date, style: .relative)
                                }
                            }
                            .font(NewspaperTheme.metaFont(size: 10))
                            .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(NewspaperTheme.rule(for: scheme)).frame(height: 0.5)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct FooterAttribution: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 4) {
            RuleView()
            Text("Headlines from The Hindu, Times of India, NDTV, Indian Express, BBC News, Al Jazeera, The Guardian and NPR. BBC content © BBC News - bbc.co.uk/news. Links open the original articles.")
                .font(NewspaperTheme.metaFont(size: 9))
                .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
