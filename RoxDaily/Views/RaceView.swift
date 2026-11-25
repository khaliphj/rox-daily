import SwiftUI

struct RaceView: View {
    @EnvironmentObject var store: Store
    @AppStorage("targetMinutes") private var targetMinutes = 90

    private var division: Division { store.profile?.division ?? .openMen }
    private var spec: RaceSpec { RaceSpec.of(division) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(value: $targetMinutes, in: 55...180, step: 5) {
                        VStack(alignment: .leading) {
                            Text("Target finish").font(.caption).foregroundStyle(Theme.muted)
                            Text(Fmt.clock(targetMinutes * 60)).font(.title2.weight(.bold)).foregroundStyle(Theme.accent)
                        }
                    }
                    let card = RaceSplits.card(target: targetMinutes * 60, division: division)
                    splitRow("Each 1 km run", Fmt.clock(card.runPerKm), "figure.run")
                    ForEach(Station.all) { station in
                        splitRow(station.name, Fmt.clock(card.stations[station.id - 1]), station.symbol)
                    }
                    splitRow("Roxzone, total", Fmt.clock(card.roxzone), "arrow.triangle.swap")
                } header: {
                    Text("Pacing card")
                } footer: {
                    Text("Splits are your target time divided the way a typical mid-pack finisher spends it. Use it as a starting plan and replace it with your own simulation splits.")
                }

                Section {
                    ForEach(Station.all) { station in
                        NavigationLink {
                            StationDetail(station: station, spec: spec)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(station.id)").font(.headline).foregroundStyle(Theme.accent).frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name).font(.subheadline.weight(.semibold))
                                    Text(station.distance + " · " + station.load(spec)).font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Stations · \(division.title)")
                } footer: {
                    Text("A 1 km run comes before every station. Sled weights include the sled.")
                }

                Section("Know the race") {
                    ForEach(RaceFact.all) { fact in
                        DisclosureGroup(fact.title) {
                            Text(fact.body).font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Race")
        }
    }

    private func splitRow(_ name: String, _ time: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 26).foregroundStyle(Theme.muted)
            Text(name)
            Spacer()
            Text(time).font(.body.monospacedDigit().weight(.semibold))
        }
    }
}

struct StationDetail: View {
    let station: Station
    let spec: RaceSpec

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    Text("STATION \(station.id)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Text(station.name).font(.title.weight(.bold))
                    HStack {
                        Pill(text: station.distance, icon: "ruler")
                        Pill(text: station.load(spec), icon: "scalemass")
                    }
                }
                Card {
                    Text("Technique").font(.headline)
                    ForEach(station.cues, id: \.self) { cue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.accent).padding(.top, 4)
                            Text(cue).foregroundStyle(Theme.ink)
                        }
                    }
                }
                section("Pacing", station.pacing)
                section("Common mistake", station.mistakes)
                section("Rule to know", station.rule)
                section("No equipment?", station.noKit)
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ text: String) -> some View {
        Card {
            Text(title).font(.headline)
            Text(text).foregroundStyle(Theme.muted)
        }
    }
}
