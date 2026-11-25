import SwiftUI

/// Full workout: header, blocks with tick-off rows, coach note, stopwatch and completion.
struct WorkoutContent: View {
    @EnvironmentObject var store: Store
    let workout: Workout
    @State private var showLog = false

    private var done: Bool { store.isDone(workout.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                HStack(alignment: .top, spacing: 14) {
                    KindBadge(kind: workout.kind, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.kind.title.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.color(for: workout.kind))
                        Text(workout.title).font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                        Text(workout.summary).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                if workout.kind.isTraining {
                    HStack(spacing: 8) {
                        Pill(text: "\(workout.minutes) min", icon: "clock")
                        Pill(text: "Effort \(workout.rpe)/10", icon: "gauge.medium")
                        if done { Pill(text: "Done", icon: "checkmark.circle.fill", color: .green) }
                    }
                    .padding(.top, 4)
                }
            }

            if let note = workout.coachNote {
                Card {
                    Label("Why this session", systemImage: "lightbulb.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(note).font(.subheadline).foregroundStyle(Theme.ink)
                }
            }

            ForEach(workout.blocks) { block in
                Card {
                    Text(block.title).font(.headline).foregroundStyle(Theme.ink)
                    if let format = block.format {
                        Text(format).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(block.items.enumerated()), id: \.offset) { i, item in
                            let key = "\(block.title)|\(i)"
                            let checked = store.isChecked(workout.id, key)
                            if i > 0 { Divider().overlay(Theme.line) }
                            Button {
                                store.toggleCheck(workout.id, key)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    QuantityText(item: item, dimmed: checked)
                                    Spacer(minLength: 0)
                                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(checked ? Theme.accent : Theme.line)
                                }
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if workout.kind.isTraining {
                StopwatchCard()
                Button {
                    if done { store.uncomplete(workout.id) } else { showLog = true }
                } label: {
                    Label(done ? "Completed · tap to undo" : "Mark complete", systemImage: done ? "checkmark.seal.fill" : "checkmark")
                }
                .buttonStyle(PillButtonStyle(fill: done ? Color.green : Theme.accent))

                if let log = store.log(for: workout.id), done, !log.notes.isEmpty {
                    Card {
                        Text("Your notes").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                        Text(log.notes).font(.subheadline).foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .sheet(isPresented: $showLog) {
            LogSheet(workout: workout).presentationDetents([.medium])
        }
    }
}

struct LogSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var rpe = 6.0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("How hard did it feel?") {
                    VStack(alignment: .leading) {
                        Text("Effort \(Int(rpe)) of 10").font(.headline)
                        Slider(value: $rpe, in: 1...10, step: 1)
                    }
                }
                Section("Notes, splits, weights") {
                    TextField("Optional", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Log session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.complete(workout.id, rpe: Int(rpe), notes: notes); dismiss() }
                }
            }
            .onAppear {
                rpe = Double(max(1, workout.rpe))
                notes = store.log(for: workout.id)?.notes ?? ""
            }
        }
    }
}

/// Stopwatch that keeps counting while the app is in the background.
struct StopwatchCard: View {
    @State private var startedAt: Date?
    @State private var banked: TimeInterval = 0

    private func elapsed(at now: Date) -> TimeInterval {
        banked + (startedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    var body: some View {
        Card {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stopwatch").font(.caption).foregroundStyle(Theme.muted)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Fmt.clock(Int(elapsed(at: context.date))))
                            .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                    }
                }
                Spacer()
                Button {
                    startedAt = nil
                    banked = 0
                } label: {
                    CircleIcon(symbol: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                Button {
                    if let s = startedAt {
                        banked += Date().timeIntervalSince(s)
                        startedAt = nil
                    } else {
                        startedAt = Date()
                    }
                } label: {
                    Image(systemName: startedAt == nil ? "play.fill" : "pause.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    var body: some View {
        ScrollView {
            WorkoutContent(workout: workout).padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(workout.date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DayRow: View {
    let workout: Workout
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            KindBadge(kind: workout.kind, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.caption).foregroundStyle(Theme.muted)
                Text(workout.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                if workout.kind.isTraining {
                    Text(workout.summary).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if workout.kind.isTraining {
                Text("\(workout.minutes) min").font(.caption).foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.line)
        }
        .contentShape(Rectangle())
    }
}

/// Poster-style "for time" session: run on the left, station on the right.
struct BonusDetailView: View {
    let workout: BonusWorkout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FOR TIME").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Text(workout.name.uppercased())
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(workout.tagline).font(.subheadline).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        Pill(text: "Time cap \(workout.capMinutes) min", icon: "clock")
                        Pill(text: workout.kit, icon: "dumbbell")
                    }
                    .padding(.top, 4)
                }
                Card {
                    VStack(spacing: 0) {
                        ForEach(workout.rows) { row in
                            if row.id > 0 { Divider().overlay(Theme.line) }
                            HStack(spacing: 8) {
                                (Text(row.run).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundColor(Theme.accent)
                                    + Text("  RUN").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink))
                                    .frame(width: 118, alignment: .leading)
                                (Text(row.amount).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundColor(Theme.accent)
                                    + Text("  " + row.move.uppercased()).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
                Card {
                    Label("How to run it", systemImage: "lightbulb.fill").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Text("Work top to bottom without planned rest. Use race weight where a station has one, and hold your race run pace rather than sprinting. Warm up for 10 minutes first and log your time in Progress.")
                        .font(.subheadline).foregroundStyle(Theme.ink)
                }
                StopwatchCard()
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationBarTitleDisplayMode(.inline)
    }
}
