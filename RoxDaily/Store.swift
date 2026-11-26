import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class Store: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var weeks: [PlanWeek] = []
    @Published private(set) var logs: [String: LogEntry] = [:]
    @Published private(set) var benchmarks: [Benchmark] = []
    @Published var reminderOn: Bool { didSet { defaults.set(reminderOn, forKey: "reminderOn"); scheduleReminder() } }
    @Published var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: "reminderHour"); scheduleReminder() } }

    /// What iOS actually has scheduled, shown in Settings.
    @Published private(set) var reminderStatus = ""

    private let defaults = UserDefaults.standard
    private var index: [String: Workout] = [:]

    init() {
        let d = UserDefaults.standard
        // UI tests start from a clean install.
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            for key in ["profile", "logs", "benchmarks", "reminderOn", "reminderHour"] { d.removeObject(forKey: key) }
        }
        reminderOn = d.bool(forKey: "reminderOn")
        reminderHour = d.object(forKey: "reminderHour") as? Int ?? 7
        profile = load("profile")
        logs = load("logs") ?? [:]
        benchmarks = load("benchmarks") ?? []
        // Launching with -demo skips onboarding; used for automated screenshots.
        if profile == nil, ProcessInfo.processInfo.arguments.contains("-demo") { profile = Store.defaultProfile() }
        rebuild()
    }

    // MARK: Persistence

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private func rebuild() {
        guard let p = profile else { weeks = []; index = [:]; return }
        weeks = PlanGenerator.weeks(for: p)
        var map: [String: Workout] = [:]
        for week in weeks { for day in week.days { map[day.id] = day } }
        index = map
    }

    // MARK: Profile

    func setProfile(_ p: Profile) {
        profile = p
        save(p, "profile")
        rebuild()
    }

    nonisolated static func defaultProfile() -> Profile {
        // HYROX Atlanta is listed for 23-25 April 2027; Saturday is the default.
        let race = Cal.calendar.date(from: DateComponents(year: 2027, month: 4, day: 24, hour: 12)) ?? Date()
        let fallback = Cal.add(140, to: Date())
        return Profile(raceDate: race > Date() ? race : fallback, planStart: Cal.day(Date()))
    }

    // MARK: Plan lookups

    func workout(on date: Date) -> Workout? { index[Cal.key(date)] }
    func workout(id: String) -> Workout? { index[id] }
    var today: Workout? { workout(on: Date()) }
    var currentWeek: PlanWeek? {
        let key = Cal.key(Date())
        return weeks.first { week in week.days.contains { $0.id == key } }
    }
    var daysToRace: Int {
        guard let p = profile else { return 0 }
        return Cal.days(from: Date(), to: p.raceDate)
    }

    // MARK: Logging

    func log(for id: String) -> LogEntry? { logs[id] }
    func isDone(_ id: String) -> Bool { logs[id]?.done == true }

    func complete(_ id: String, rpe: Int, notes: String) {
        var entry = logs[id] ?? LogEntry(completedAt: Date())
        entry.completedAt = Date()
        entry.feltRPE = rpe
        entry.notes = notes
        entry.done = true
        logs[id] = entry
        save(logs, "logs")
    }

    func uncomplete(_ id: String) {
        guard var entry = logs[id] else { return }
        entry.done = false
        entry.feltRPE = nil
        logs[id] = entry
        save(logs, "logs")
    }

    func toggleCheck(_ id: String, _ key: String) {
        var entry = logs[id] ?? LogEntry(completedAt: Date())
        if let i = entry.checked.firstIndex(of: key) { entry.checked.remove(at: i) } else { entry.checked.append(key) }
        logs[id] = entry
        save(logs, "logs")
    }

    func isChecked(_ id: String, _ key: String) -> Bool { logs[id]?.checked.contains(key) ?? false }

    // MARK: Stats

    /// Training sessions scheduled up to and including today.
    private var dueSessions: [Workout] {
        let todayKey = Cal.key(Date())
        let startKey = profile.map { Cal.key($0.planStart) } ?? ""
        return weeks.flatMap { $0.days }.filter { $0.kind.isTraining && $0.id <= todayKey && $0.id >= startKey }
    }
    var completedCount: Int { dueSessions.filter { isDone($0.id) }.count }
    var dueCount: Int { dueSessions.count }
    var totalMinutes: Int { weeks.flatMap { $0.days }.filter { isDone($0.id) }.reduce(0) { $0 + $1.minutes } }

    /// Consecutive scheduled sessions completed, counting back from the most recent.
    var streak: Int {
        let todayKey = Cal.key(Date())
        var count = 0
        for w in dueSessions.reversed() {
            if isDone(w.id) { count += 1 } else if w.id == todayKey { continue } else { break }
        }
        return count
    }

    func done(in week: PlanWeek) -> Int { week.days.filter { $0.kind.isTraining && isDone($0.id) }.count }

    // MARK: Benchmarks

    func addBenchmark(_ b: Benchmark) {
        benchmarks.append(b)
        benchmarks.sort { $0.date > $1.date }
        save(benchmarks, "benchmarks")
    }

    func deleteBenchmark(_ b: Benchmark) {
        benchmarks.removeAll { $0.id == b.id }
        save(benchmarks, "benchmarks")
    }

    // MARK: Daily reminder

    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily"])
        guard reminderOn else { reminderStatus = ""; return }
        let hour = reminderHour
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
                reminderStatus = "Notifications are turned off for Rox Daily in the iPhone's Settings app."
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Today's session is ready"
            content.body = "Open Rox Daily to see your workout."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "daily", content: content, trigger: trigger))
            await refreshReminderStatus()
        }
    }

    /// Reads the pending request back from iOS rather than assuming it was stored.
    func refreshReminderStatus() async {
        guard reminderOn else { reminderStatus = ""; return }
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let hours = pending.filter { $0.identifier == "daily" }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour }
        if let hour = hours.first {
            reminderStatus = "Scheduled daily at \(hour):00"
        } else {
            reminderStatus = "No reminder is scheduled yet."
        }
    }
}
