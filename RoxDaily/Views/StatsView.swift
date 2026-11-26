import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false

    static let tests = ["5K run", "1 km run", "1000 m SkiErg", "1000 m row", "100 wall balls", "PFT fitness test", "Half simulation", "Full simulation", "Race"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        stat("\(store.completedCount)/\(store.dueCount)", "Sessions")
                        stat("\(store.streak)", "Streak")
                        stat(String(format: "%.1f h", Double(store.totalMinutes) / 60), "Trained")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    if store.benchmarks.isEmpty {
                        Text("Log a test now and repeat it every 4-6 weeks to see the plan working. Update your 5K time in Settings when it improves so your paces keep up.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    ForEach(store.benchmarks) { b in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(b.test).font(.subheadline.weight(.semibold))
                                Text(b.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text(Fmt.clock(b.seconds)).font(.body.monospacedDigit().weight(.semibold))
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.deleteBenchmark(b) }
                        }
                    }
                } header: {
                    Text("Benchmarks")
                }

                Section("Weeks") {
                    ForEach(store.weeks) { week in
                        HStack {
                            Text("W\(week.number)").font(.caption.monospacedDigit()).frame(width: 34, alignment: .leading)
                            ProgressView(value: Double(store.done(in: week)), total: Double(max(week.sessions, 1)))
                                .tint(store.done(in: week) >= week.sessions ? Color.green : Theme.accent)
                            Text("\(store.done(in: week))/\(week.sessions)").font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddBenchmark().presentationDetents([.medium]) }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

struct AddBenchmark: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var test = StatsView.tests[0]
    @State private var date = Date()
    @State private var minutes = 25
    @State private var seconds = 0

    var body: some View {
        NavigationStack {
            Form {
                Picker("Test", selection: $test) {
                    ForEach(StatsView.tests, id: \.self) { Text($0).tag($0) }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Stepper("Minutes: \(minutes)", value: $minutes, in: 0...240)
                Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
            }
            .navigationTitle("Add result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addBenchmark(Benchmark(test: test, date: date, seconds: minutes * 60 + seconds))
                        dismiss()
                    }
                }
            }
        }
    }
}
