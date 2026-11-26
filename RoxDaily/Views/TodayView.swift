import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var showSettings = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting).font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button { showSettings = true } label: { CircleIcon(symbol: "gearshape") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Settings")
                    }
                    .padding(.top, 4)

                    countdown

                    SectionTitle("Today's session")
                    if let workout = store.today {
                        WorkoutContent(workout: workout)
                    } else {
                        Card {
                            Text("No session scheduled").font(.headline)
                            Text("Today is outside your plan. Open settings to set a new race date.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }

                    if let next = store.workout(on: Cal.add(1, to: Date())) {
                        SectionTitle("Tomorrow")
                        NavigationLink(value: next.id) {
                            Card { DayRow(workout: next, done: store.isDone(next.id)) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) { StatusBarStrip() }
            .navigationDestination(for: String.self) { id in
                if let w = store.workout(id: id) { WorkoutDetailView(workout: w) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(max(store.daysToRace, 0))")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                    Text(store.daysToRace <= 0 ? "Race day" : "days to HYROX \(store.profile?.city ?? "")")
                        .font(.subheadline.weight(.medium)).opacity(0.9)
                }
                Spacer()
                if let week = store.currentWeek {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(week.phase.title + (week.isDeload ? " · Deload" : ""))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.2), in: Capsule())
                        Text("Week \(week.number) of \(store.weeks.count)").font(.caption).opacity(0.9)
                        Text("\(store.done(in: week))/\(week.sessions) sessions").font(.caption).opacity(0.9)
                    }
                }
            }
            if let week = store.currentWeek {
                ProgressView(value: Double(week.number), total: Double(max(store.weeks.count, 1)))
                    .tint(.white)
                    .background(Color.white.opacity(0.25), in: Capsule())
                Text(week.phase.focus).font(.footnote).opacity(0.9)
            }
        }
        .foregroundStyle(Color.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.accent, Color(red: 0.30, green: 0.62, blue: 1.0)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }
}
