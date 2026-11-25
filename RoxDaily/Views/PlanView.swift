import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: Store
    @State private var tab = "Plan"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Training").font(.largeTitle.weight(.bold)).foregroundStyle(Theme.ink)
                            Spacer()
                            if tab == "Plan" {
                                Button("This week") {
                                    if let n = store.currentWeek?.number { withAnimation { proxy.scrollTo("w\(n)", anchor: .top) } }
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                        SegmentedPills(options: ["Plan", "For Time"], selection: $tab) { $0 }

                        if tab == "Plan" {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(store.weeks) { week in weekCard(week).id("w\(week.number)") }
                            }
                        } else {
                            ForEach(BonusWorkout.all) { bonus in
                                NavigationLink {
                                    BonusDetailView(workout: bonus)
                                } label: {
                                    Card {
                                        HStack(spacing: 12) {
                                            IconTile(symbol: "stopwatch.fill")
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(bonus.name).font(.headline).foregroundStyle(Theme.ink)
                                                Text(bonus.tagline).font(.caption).foregroundStyle(Theme.muted)
                                                Text("\(bonus.rows.count) rounds · cap \(bonus.capMinutes) min · \(bonus.kit)")
                                                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                                            }
                                            Spacer(minLength: 0)
                                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.line)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Theme.bg)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { id in
                    if let w = store.workout(id: id) { WorkoutDetailView(workout: w) }
                }
                .onAppear {
                    if let n = store.currentWeek?.number { proxy.scrollTo("w\(n)", anchor: .top) }
                }
            }
        }
    }

    private func weekCard(_ week: PlanWeek) -> some View {
        let current = week.number == store.currentWeek?.number
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week \(week.number)").font(.headline).foregroundStyle(Theme.ink)
                Pill(text: week.phase.title + (week.isDeload ? " · Deload" : ""), color: current ? Theme.accent : Theme.muted)
                Spacer()
                Text("\(store.done(in: week))/\(week.sessions)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(week.days.enumerated()), id: \.element.id) { i, day in
                        if i > 0 { Divider().overlay(Theme.line) }
                        NavigationLink(value: day.id) {
                            DayRow(workout: day, done: store.isDone(day.id)).padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
