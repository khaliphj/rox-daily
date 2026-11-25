import SwiftUI

struct NewsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL
    @State private var topic: NewsTopic = .local
    @State private var cache: [NewsTopic: [NewsItem]] = [:]
    @State private var loadingTopic: NewsTopic?
    @State private var failed = false

    private var city: String {
        let c = store.profile?.city.trimmingCharacters(in: .whitespaces) ?? ""
        return c.isEmpty ? "Atlanta" : c
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("News").font(.largeTitle.weight(.bold)).foregroundStyle(Theme.ink)
                    SegmentedPills(options: NewsTopic.allCases, selection: $topic) { $0.title(city: city) }

                    if topic == .local || topic == .events {
                        Card {
                            FieldRow(symbol: "flag.checkered", label: "Your race", value: "HYROX \(city)")
                            Divider().overlay(Theme.line)
                            FieldRow(symbol: "calendar", label: "Date",
                                     value: (store.profile?.raceDate.formatted(date: .long, time: .omitted) ?? "") + " · \(max(store.daysToRace, 0)) days to go")
                            Divider().overlay(Theme.line)
                            link("Race finder and tickets", "ticket.fill", "https://hyrox.com/find-my-race/")
                            Divider().overlay(Theme.line)
                            link("Training clubs near \(city)", "mappin.and.ellipse",
                                 "https://www.google.com/maps/search/" + (("HYROX training club " + city).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "HYROX"))
                            Divider().overlay(Theme.line)
                            link("Current rulebook", "book.fill", "https://hyrox.com/rulebook/")
                        }
                    }

                    SectionTitle(topic == .local ? "Latest in \(city)" : "Latest")
                    if let items = cache[topic], !items.isEmpty {
                        ForEach(items) { item in
                            Button {
                                if let url = URL(string: item.link) { openURL(url) }
                            } label: {
                                Card {
                                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 6) {
                                        if !item.source.isEmpty { Text(item.source).foregroundStyle(Theme.accent) }
                                        if let d = item.date { Text(d.formatted(.relative(presentation: .named, unitsStyle: .wide))) }
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(.caption.weight(.medium)).foregroundStyle(Theme.muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Card {
                            if loadingTopic == topic {
                                HStack(spacing: 10) { ProgressView(); Text("Loading stories").foregroundStyle(Theme.muted) }
                            } else if failed {
                                Text("Could not load stories").font(.subheadline.weight(.semibold))
                                Text("Check your connection, then pull down to try again.").font(.caption).foregroundStyle(Theme.muted)
                            } else {
                                Text("No recent stories for this topic. Pull down to refresh.").font(.subheadline).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load(force: true) }
            .task(id: topic) { await load(force: false) }
        }
    }

    private func link(_ title: String, _ icon: String, _ address: String) -> some View {
        Button {
            if let url = URL(string: address) { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: icon, size: 40)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load(force: Bool) async {
        let current = topic
        if !force, cache[current] != nil { return }
        loadingTopic = current
        failed = false
        do {
            // Detached from the view's task so a list refresh cannot cancel the request.
            let place = city
            let items = try await Task { try await NewsService.fetch(current, city: place) }.value
            cache[current] = items
        } catch {
            if cache[current] == nil { failed = true }
        }
        if loadingTopic == current { loadingTopic = nil }
    }
}
