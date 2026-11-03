import AppIntents
import SwiftUI
import WidgetKit

struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { NewspaperTheme.paper(for: scheme) }
}

private struct WidgetMasthead: View {
    let entry: NewsEntry
    let compact: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("GOOD NEWS")
                    .font(NewspaperTheme.mastheadFont(size: compact ? 13 : 17))
                    .foregroundStyle(NewspaperTheme.ink(for: scheme))
                Spacer()
                if !compact {
                    Text(entry.updatedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(NewspaperTheme.metaFont(size: 9))
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                }
            }
            HStack(spacing: 6) {
                ForEach(NewsPage.allCases, id: \.self) { p in
                    Button(intent: SetPageIntent(page: p)) {
                        Text(p.title)
                            .font(NewspaperTheme.metaFont(size: 9).weight(p == entry.page ? .bold : .medium))
                            .kerning(0.8)
                            .foregroundStyle(p == entry.page ? NewspaperTheme.ink(for: scheme) : NewspaperTheme.secondaryInk(for: scheme))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .overlay(alignment: .bottom) {
                                if p == entry.page {
                                    Rectangle().fill(NewspaperTheme.ink(for: scheme)).frame(height: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if entry.isStale {
                    Text("STALE")
                        .font(NewspaperTheme.metaFont(size: 8).weight(.bold))
                        .kerning(0.8)
                        .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                }
            }
            Rectangle().fill(NewspaperTheme.ink(for: scheme)).frame(height: 1.5)
            Rectangle().fill(NewspaperTheme.rule(for: scheme)).frame(height: 0.5)
        }
    }
}

private struct HeadlineRow: View {
    let item: FeedItem
    let size: CGFloat
    let lines: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.title)
                .font(NewspaperTheme.headlineFont(size: size))
                .foregroundStyle(NewspaperTheme.ink(for: scheme))
                .lineLimit(lines)
                .multilineTextAlignment(.leading)
            Text(item.source.uppercased())
                .font(NewspaperTheme.metaFont(size: 7.5).weight(.semibold))
                .kerning(0.6)
                .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyState: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 4) {
            Text("No headlines")
                .font(NewspaperTheme.headlineFont(size: 13))
                .foregroundStyle(NewspaperTheme.ink(for: scheme))
            Button(intent: RefreshIntent()) {
                Text("RETRY")
                    .font(NewspaperTheme.metaFont(size: 9).weight(.bold))
                    .kerning(1)
                    .foregroundStyle(NewspaperTheme.ink(for: scheme))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .overlay(Rectangle().stroke(NewspaperTheme.ink(for: scheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SmallWidgetView: View {
    let entry: NewsEntry
    @Environment(\.colorScheme) private var scheme

    private var item: FeedItem? {
        guard !entry.items.isEmpty else { return nil }
        let slot = max(0, Int(entry.date.timeIntervalSince(entry.updatedAt) / 900))
        return entry.items[slot % entry.items.count]
    }

    var body: some View {
        if let item {
            Link(destination: item.link ?? URL(string: "goodnews://open")!) {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetMasthead(entry: entry, compact: true)
                    Spacer(minLength: 2)
                    HeadlineRow(item: item, size: 14, lines: 4)
                    Spacer(minLength: 0)
                }
                .padding(10)
            }
        } else {
            EmptyState().padding(10)
        }
    }
}

struct MediumWidgetView: View {
    let entry: NewsEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if entry.items.isEmpty {
            VStack(spacing: 4) {
                WidgetMasthead(entry: entry, compact: false)
                EmptyState()
            }
            .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                WidgetMasthead(entry: entry, compact: false)
                ForEach(Array(entry.items.prefix(3).enumerated()), id: \.element.id) { _, item in
                    if let url = item.link {
                        Link(destination: url) { HeadlineRow(item: item, size: 12.5, lines: 2) }
                    } else {
                        HeadlineRow(item: item, size: 12.5, lines: 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

struct LargeWidgetView: View {
    let entry: NewsEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if entry.items.isEmpty {
            VStack(spacing: 4) {
                WidgetMasthead(entry: entry, compact: false)
                EmptyState()
            }
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                WidgetMasthead(entry: entry, compact: false)
                let main = Array(entry.items.prefix(4))
                let side = Array(entry.items.dropFirst(4).prefix(3))
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(main) { item in
                            if let url = item.link {
                                Link(destination: url) { HeadlineRow(item: item, size: 13.5, lines: 3) }
                            } else {
                                HeadlineRow(item: item, size: 13.5, lines: 3)
                            }
                            Rectangle().fill(NewspaperTheme.rule(for: scheme)).frame(height: 0.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if !side.isEmpty {
                        Rectangle().fill(NewspaperTheme.rule(for: scheme)).frame(width: 0.5)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("INSIDE")
                                .font(NewspaperTheme.metaFont(size: 8).weight(.bold))
                                .kerning(1)
                                .foregroundStyle(NewspaperTheme.secondaryInk(for: scheme))
                            ForEach(side) { item in
                                if let url = item.link {
                                    Link(destination: url) { HeadlineRow(item: item, size: 11, lines: 4) }
                                } else {
                                    HeadlineRow(item: item, size: 11, lines: 4)
                                }
                            }
                        }
                        .frame(width: 110)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}
