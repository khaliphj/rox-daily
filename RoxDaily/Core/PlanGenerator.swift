import Foundation

/// Builds the whole plan from a profile. Deterministic: the same profile always
/// yields the same plan, so only completion logs need to be stored.
enum PlanGenerator {

    private enum Slot { case strength, quality, easy, hybrid, long, support }

    /// Monday-first weekly layout for each training frequency.
    private static func template(_ days: Int) -> [Slot?] {
        switch days {
        case ...3: return [nil, .quality, nil, .hybrid, nil, .long, nil]
        case 4: return [.strength, .quality, nil, .hybrid, nil, .long, nil]
        case 5: return [.strength, .quality, nil, .hybrid, .easy, .long, nil]
        default: return [.strength, .quality, .easy, .hybrid, .support, .long, nil]
        }
    }

    static func phases(totalWeeks n: Int) -> [Phase] {
        guard n > 1 else { return [.raceWeek] }
        guard n > 3 else { return Array(repeating: Phase.specific, count: n - 1) + [.raceWeek] }
        let r = n - 2
        let specific = min(5, max(1, Int((Double(r) * 0.3).rounded())))
        let build = min(6, max(1, Int((Double(r) * 0.35).rounded())))
        let base = max(0, r - specific - build)
        return Array(repeating: .base, count: base)
            + Array(repeating: .build, count: build)
            + Array(repeating: .specific, count: r - base - build)
            + [.taper, .raceWeek]
    }

    static func weeks(for p: Profile) -> [PlanWeek] {
        let start = Cal.monday(p.planStart)
        let raceDay = Cal.day(p.raceDate)
        let raceMonday = Cal.monday(raceDay)
        let n = max(1, Cal.days(from: start, to: raceMonday) / 7 + 1)
        let phaseList = phases(totalWeeks: n)
        let slots = template(p.daysPerWeek)
        var result: [PlanWeek] = []
        var phaseCounter: [Phase: Int] = [:]

        for i in 0..<n {
            let phase = phaseList[i]
            let inPhase = phaseCounter[phase, default: 0]
            phaseCounter[phase] = inPhase + 1
            let weeksToRace = n - 1 - i
            let loading = phase == .base || phase == .build || phase == .specific
            let deload = loading && i % 4 == 3 && weeksToRace > 2
            let ramp = n > 3 ? min(1, Double(i) / Double(max(1, n - 4))) : 1
            let weekStart = Cal.add(i * 7, to: start)
            let b = Builder(p: p, phase: phase, week: i, inPhase: inPhase, weeksToRace: weeksToRace, deload: deload, ramp: ramp)

            var days: [Workout] = []
            for d in 0..<7 {
                let date = Cal.add(d, to: weekStart)
                let toRace = Cal.days(from: date, to: raceDay)
                let draft: Draft
                if toRace < 0 {
                    draft = toRace == -1 ? b.postRace() : b.rest("Recover. Easy walking and good food. Start thinking about the next one.")
                } else if toRace <= 6 && phase == .raceWeek {
                    draft = b.raceWeekDay(toRace)
                } else if let slot = slots[d] {
                    switch slot {
                    case .strength: draft = b.strength()
                    case .quality: draft = b.quality()
                    case .easy: draft = b.easyRun()
                    case .hybrid: draft = b.hybrid()
                    case .long: draft = b.long()
                    case .support: draft = b.support()
                    }
                } else {
                    draft = b.rest(nil)
                }
                days.append(Workout(
                    id: Cal.key(date), date: date, weekNumber: i + 1, phase: phase, isDeload: deload,
                    kind: draft.kind, title: draft.title, summary: draft.summary, minutes: draft.minutes,
                    rpe: draft.rpe, blocks: draft.blocks, coachNote: draft.note
                ))
            }
            result.append(PlanWeek(number: i + 1, phase: phase, isDeload: deload, start: weekStart, days: days))
        }
        return result
    }
}

struct Draft {
    let kind: SessionKind
    let title: String
    let summary: String
    let minutes: Int
    let rpe: Int
    let blocks: [WorkoutBlock]
    let note: String?
}

// MARK: - Session builder

struct Builder {
    let p: Profile
    let phase: Phase
    let week: Int
    let inPhase: Int
    let weeksToRace: Int
    let deload: Bool
    /// 0 at the start of the plan, 1 at peak volume.
    let ramp: Double

    var pace: Paces { Paces(fiveKSeconds: p.fiveKSeconds) }
    var spec: RaceSpec { RaceSpec.of(p.division) }
    private var scale: Double { p.level.volume * (deload ? 0.65 : 1) }

    /// Scaled count (reps, rounds).
    func n(_ x: Double) -> Int { max(1, Int((x * scale).rounded())) }
    /// Scaled value rounded to a step (metres, minutes).
    func q(_ x: Double, _ step: Double = 5) -> Int { max(Int(step), Int((x * scale / step).rounded() * step)) }
    private func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * ramp }

    // MARK: Movements with equipment substitutions

    func ski(_ m: Int) -> String {
        if p.hasSkiErg { return "\(m) m SkiErg" }
        if p.hasRower { return "\(m) m row (SkiErg swap)" }
        return "\(max(10, m / 10)) ball slams or band pull-downs (SkiErg swap)"
    }
    func row(_ m: Int) -> String {
        if p.hasRower { return "\(m) m row" }
        if p.hasSkiErg { return "\(m) m SkiErg (rower swap)" }
        return "\(max(1, m / 250)) min hard on a bike or any cardio machine (rower swap)"
    }
    func push(_ m: Int, _ pct: Double = 1) -> String {
        if p.hasSled { return "\(m) m sled push @ \(Fmt.kg((spec.sledPush * pct / 2.5).rounded() * 2.5))" }
        return "\(m) m heavy walking lunges, or \(m * 2) s pushing an unpowered treadmill belt (sled push swap)"
    }
    func pull(_ m: Int, _ pct: Double = 1) -> String {
        if p.hasSled { return "\(m) m sled pull @ \(Fmt.kg((spec.sledPull * pct / 2.5).rounded() * 2.5))" }
        return "\(max(8, m / 2)) heavy seated cable rows or bent-over rows (sled pull swap)"
    }
    func wb(_ reps: Int) -> String {
        if p.hasWallBall { return "\(reps) wall balls @ \(Fmt.kg(spec.wallBall))" }
        return "\(reps) light dumbbell thrusters (wall ball swap)"
    }
    func carry(_ m: Int, extra: Double = 0) -> String { "\(m) m farmers carry @ 2 x \(Fmt.kg(spec.farmers + extra))" }
    func lunge(_ m: Int, extra: Double = 0) -> String { "\(m) m sandbag lunges @ \(Fmt.kg(spec.sandbag + extra))" }
    func bbj(_ m: Int) -> String { "\(m) m burpee broad jumps" }

    // MARK: Shared blocks

    var runWarmup: WorkoutBlock {
        WorkoutBlock("Warm-up", format: "10-12 minutes, nothing hard", [
            "8 min easy jog at \(pace.easyText)",
            "Leg swings, walking lunges, ankle hops: 2 min",
            "4 x 20 s strides, walk back between"
        ])
    }
    var gymWarmup: WorkoutBlock {
        WorkoutBlock("Warm-up", format: "10 minutes, build gradually", [
            "5 min easy on any erg or a light jog",
            "World's greatest stretch x 5 per side, 10 air squats, 10 scap pull-ups or band pull-aparts",
            "2 light build-up sets of the first exercise"
        ])
    }
    var coolDown: WorkoutBlock {
        WorkoutBlock("Cool-down", format: "5-10 minutes", [
            "5 min easy walk or jog until breathing is normal",
            "Stretch calves, hip flexors, quads and lats, 45 s each"
        ])
    }
    private var deloadTag: String { deload ? " (deload)" : "" }
    private func note(_ s: String) -> String {
        deload ? s + " Deload week: same shape, about a third less work. Finish feeling you could do more." : s
    }

    // MARK: Rest

    func rest(_ note: String?) -> Draft {
        Draft(kind: .rest, title: "Rest Day", summary: "No training. Walk, eat well, sleep.", minutes: 0, rpe: 0,
              blocks: [WorkoutBlock("Optional", format: "Only if you feel like moving", [
                "20-30 min easy walk",
                "10 min mobility: hips, ankles, thoracic spine"
              ])],
              note: note ?? "Fitness is built while you recover from training, not during it. Keep at least one day a week completely free.")
    }

    // MARK: Easy and long runs

    func easyRun() -> Draft {
        let mins = phase == .taper ? 30 : q(lerp(30, 42), 5)
        let strides = week % 2 == 1
        var main = ["\(mins) min continuous at \(pace.easyText)", "Effort check: you can speak in full sentences the whole way"]
        if strides { main.append("Finish with 6 x 20 s relaxed strides, full walk-back recovery") }
        return Draft(kind: .easyRun, title: "Easy Zone 2 Run" + deloadTag,
                     summary: "\(mins) min conversational" + (strides ? " + strides" : ""),
                     minutes: mins + 10, rpe: 3,
                     blocks: [
                        WorkoutBlock("Main set", format: "Zone 2, about 60-70% of max heart rate", main),
                        WorkoutBlock("Cool-down", format: "5 minutes", ["Walk 3 min", "Calf and hip flexor stretch, 45 s each side"])
                     ],
                     note: note("Around 80% of your running should feel this easy. It builds the aerobic base that lets you recover between stations, and it is the session people most often run too fast."))
    }

    func support() -> Draft {
        let erg = q(lerp(20, 30), 5)
        return Draft(kind: .recovery, title: "Engine + Upper Body" + deloadTag,
                     summary: "\(erg) min easy erg, pulling, grip and core",
                     minutes: erg + 30, rpe: 4,
                     blocks: [
                        WorkoutBlock("Easy engine", format: "Zone 2, nose-breathing effort", [
                            "\(erg) min alternating 5 min blocks: " + (p.hasSkiErg ? "SkiErg" : "bike") + " / " + (p.hasRower ? "rower" : "bike"),
                            "Use it as technique practice: long strokes, low stroke rate"
                        ]),
                        WorkoutBlock("Upper body and grip", format: "3 rounds, 60 s rest between exercises", [
                            "Pull-ups or lat pull-downs x \(n(8))",
                            "Dumbbell push press x \(n(10))",
                            "Single-arm dumbbell row x \(n(10)) per side",
                            "Hand-release push-ups x \(n(12))",
                            "Dead hang, \(q(40, 5)) s"
                        ]),
                        WorkoutBlock("Core", format: "3 rounds, minimal rest", [
                            "Front plank 45 s", "Side plank 30 s per side", "Dead bug x 10 per side"
                        ])
                     ],
                     note: note("A low-stress day that adds aerobic volume without more pounding on your legs, and builds the pulling strength and grip that protect you on the sled pull and farmers carry."))
    }

    func long() -> Draft {
        if !deload {
            if phase == .specific {
                if weeksToRace == 3 { return simulation(.full) }
                if weeksToRace == 5 { return simulation(p.level == .advanced ? .full : .halfFront) }
                if weeksToRace == 2 { return simulation(.halfBack) }
            }
            if phase == .build && inPhase % 3 == 2 { return simulation(inPhase % 2 == 0 ? .halfFront : .halfBack) }
            if phase == .taper { return taperLong() }
        }
        let peak: Double = p.level == .beginner ? 70 : (p.level == .intermediate ? 85 : 95)
        let start: Double = p.level == .beginner ? 40 : (p.level == .intermediate ? 50 : 60)
        var mins = Int(((start + (peak - start) * ramp) * (deload ? 0.7 : 1) / 5).rounded() * 5)
        if phase == .specific { mins = Int((Double(mins) * 0.85 / 5).rounded() * 5) }
        var main = ["\(mins) min at \(pace.easyText)"]
        var title = "Long Easy Run"
        var summary = "\(mins) min zone 2"
        if !deload && phase == .build && inPhase % 2 == 1 {
            main = ["\(mins - 15) min at \(pace.easyText)", "Final 15 min steady, building toward \(pace.thresholdText)"]
            title = "Long Run, Fast Finish"; summary = "\(mins) min, last 15 steady"
        } else if !deload && phase == .specific {
            main = ["\(mins - 20) min at \(pace.easyText)", "Then 4 x 1 km at race pace \(pace.raceText), 60 s walk between"]
            title = "Long Run + Race Pace"; summary = "\(mins) min with 4 x 1 km at race pace"
        } else if !deload && phase == .base && inPhase % 3 == 2 {
            main.append("Straight after: 3 rounds of \(wb(n(15))) + \(bbj(q(10, 5))), easy pace")
            title = "Long Run + Station Finish"; summary = "\(mins) min zone 2, then light stations"
        }
        main.append("Carry water past 60 min. Practise the gel or drink you plan to use on race day.")
        return Draft(kind: .longRun, title: title + deloadTag, summary: summary, minutes: mins + 10, rpe: 4,
                     blocks: [
                        WorkoutBlock("Main set", format: "Start slower than you think. Flat or rolling route.", main),
                        coolDown
                     ],
                     note: note("The long run builds durability for 8 km of running broken up over more than an hour. Time on feet matters more than pace."))
    }

    private func taperLong() -> Draft {
        Draft(kind: .easyRun, title: "Taper Run + Strides", summary: "40 min easy with race-pace pickups", minutes: 45, rpe: 4,
              blocks: [
                WorkoutBlock("Main set", format: "Relaxed. You should finish fresher than you started.", [
                    "30 min at \(pace.easyText)",
                    "4 x 2 min at race pace \(pace.raceText), 2 min easy jog between",
                    "4 x 20 s strides"
                ]),
                coolDown
              ],
              note: "Volume is down about 40% this week but the legs still touch race pace. Resist the urge to test yourself.")
    }

    // MARK: Quality running

    func quality() -> Draft {
        let v = deload ? 0 : inPhase
        switch phase {
        case .base:
            switch v % 4 {
            case 0:
                let reps = n(8)
                return run("400 m Repeats", "\(reps) x 400 m fast, 90 s jog", 8, [
                    "\(reps) x 400 m at \(pace.speedText), about \(pace.rep(400, at: pace.speed)) per rep",
                    "90 s easy jog or walk between reps",
                    "Run them evenly: the last rep should match the first"
                ], "Short, fast repeats build leg speed and running economy while the overall load is still low.")
            case 1:
                let reps = n(3)
                return run("Cruise Intervals", "\(reps) x 8 min at threshold", 7, [
                    "\(reps) x 8 min at \(pace.thresholdText)", "2 min easy jog between",
                    "Comfortably hard: you could say a short sentence, not hold a conversation"
                ], "Threshold running is the single best predictor of your run splits. This is the pace your body learns to clear lactate at.", kind: .tempo)
            case 2:
                let reps = n(5)
                return run("800 m Repeats", "\(reps) x 800 m at 5K pace", 8, [
                    "\(reps) x 800 m at \(pace.intervalText), about \(pace.rep(800, at: pace.interval)) per rep",
                    "2 min easy jog between"
                ], "Longer repeats at 5K pace raise your aerobic ceiling and set up the 1 km work in the next phase.")
            default:
                let mins = q(20, 5)
                return run("Steady Tempo", "\(mins) min continuous threshold", 7, [
                    "\(mins) min continuous at \(pace.thresholdText)",
                    "Lock into rhythm. If you are fading in the last 5 minutes you started too fast."
                ], "Continuous tempo teaches you to hold a hard, even effort without the mental break of a rest interval.", kind: .tempo)
            }
        case .build:
            switch v % 4 {
            case 0:
                let reps = n(5 + Double(min(inPhase, 4)) * 0.5)
                return run("1 km Repeats", "\(reps) x 1 km at 5K pace, 90 s rest", 8, [
                    "\(reps) x 1 km at \(pace.intervalText)", "90 s walk or jog between",
                    "This is faster than race pace on purpose"
                ], "HYROX is eight 1 km runs. Running them faster than race pace in training makes race pace feel controlled.")
            case 1:
                let reps = n(3)
                return run("2 km Threshold Reps", "\(reps) x 2 km at threshold", 7, [
                    "\(reps) x 2 km at \(pace.thresholdText), about \(pace.rep(2000, at: pace.threshold)) per rep",
                    "2 min easy jog between"
                ], "Longer threshold reps extend how long you can sit just under the red line.", kind: .tempo)
            case 2:
                return run("Threshold Pyramid", "400-800-1000-800-400 m", 8, [
                    "Pyramid of 400 m, 800 m, 1000 m, 800 m, 400 m at \(pace.intervalText)",
                    "90 s easy jog after each",
                    p.level == .advanced ? "Advanced: repeat the 1000 m and 800 m once more" : "Keep every rep at the same pace"
                ], "Changing distance keeps you honest about pace control, which is the skill that matters between stations.")
            default:
                let reps = n(6)
                return run("Compromised 800s", "\(reps) x 800 m, each followed by \(n(15)) wall balls", 8, [
                    "\(reps) rounds: 800 m at \(pace.raceText), then straight into \(wb(n(15)))",
                    "90 s rest after the wall balls",
                    "Note how the first 200 m of each run feels and settle quickly"
                ], "Your first taste of running at race pace on legs that have just worked. The aim is finding rhythm fast.", kind: .compromised)
            }
        case .specific:
            switch v % 3 {
            case 0:
                let reps = min(8, n(6 + Double(inPhase)))
                return run("Race-Pace Kilometres", "\(reps) x 1 km at race pace, 60 s walk", 7, [
                    "\(reps) x 1 km at \(pace.raceText), about \(pace.rep(1000, at: pace.race)) per rep",
                    "60 s walk between, the length of a quick Roxzone transition",
                    "Every rep within 5 s of each other"
                ], "This is the race's running, rehearsed. Memorise what this pace feels like so you can find it without a watch.")
            case 1:
                let reps = n(3)
                return run("2 km Threshold Reps", "\(reps) x 2 km at threshold", 7, [
                    "\(reps) x 2 km at \(pace.thresholdText)", "90 s easy jog between"
                ], "Keeps your threshold topped up while most of the week turns race specific.", kind: .tempo)
            default:
                let reps = n(4)
                return run("Fast Then Race Pace", "\(reps) x (400 m fast + 1 km race pace)", 8, [
                    "\(reps) rounds: 400 m at \(pace.speedText), 30 s walk, then 1 km at \(pace.raceText)",
                    "2 min rest between rounds"
                ], "The fast 400 stands in for a station: it spikes your heart rate, then you practise settling into race pace anyway.")
            }
        default:
            return run("Race-Pace Sharpener", "4 x 1 km at race pace", 6, [
                "4 x 1 km at \(pace.raceText)", "90 s walk between", "Stop there even if you feel great"
            ], "Enough to keep the pace familiar. Fitness is already banked; this week you are just keeping the engine warm.")
        }
    }

    private func run(_ title: String, _ summary: String, _ rpe: Int, _ main: [String], _ why: String, kind: SessionKind = .intervals) -> Draft {
        Draft(kind: kind, title: title + deloadTag, summary: summary, minutes: deload ? 40 : 50, rpe: deload ? rpe - 1 : rpe,
              blocks: [runWarmup, WorkoutBlock("Main set", format: "Track, treadmill or a flat measured loop", main), coolDown],
              note: note(why))
    }

    // MARK: Strength

    func strength() -> Draft {
        let a = week % 2 == 0
        let sets = deload ? 2 : (phase == .taper ? 2 : 4)
        var lifts: [String]
        var sled: [String]
        var title: String
        var why: String
        switch phase {
        case .base:
            title = a ? "Strength: Squat Focus" : "Strength: Deadlift Focus"
            lifts = a ? [
                "Back squat \(sets) x 5, leave 2 reps in reserve, 2-3 min rest",
                "Romanian deadlift 3 x 8",
                "Rear-foot-elevated split squat 3 x 8 per side",
                "Pull-ups or lat pull-downs 3 x \(n(8))"
            ] : [
                "Trap-bar or conventional deadlift \(sets) x 5, leave 2 reps in reserve, 2-3 min rest",
                "Goblet or front squat 3 x 8",
                "Walking lunges 3 x 10 per side, dumbbells",
                "Dumbbell push press 3 x 8"
            ]
            sled = [push(q(20, 5), 0.75) + " x 4, 90 s rest", pull(q(20, 5), 0.75) + " x 4, 90 s rest", "Technique first: low hips, short steps, sled never stops mid-lane"]
            why = "Base phase strength is heavy and unhurried, with long rests. Stronger legs make race weights a smaller fraction of your maximum, so every station costs less."
        case .build:
            title = a ? "Strength: Heavy Sleds" : "Strength: Power + Carries"
            lifts = a ? [
                "Front squat \(sets) x 4, heavy, 2-3 min rest",
                "Romanian deadlift 3 x 6",
                "Sandbag or dumbbell walking lunges 3 x 20 m, heavier than race bag",
                "Single-arm dumbbell row 3 x 10 per side"
            ] : [
                "Trap-bar deadlift \(sets) x 4, fast up, 2-3 min rest",
                "Box step-ups 3 x 8 per side, loaded",
                "Kettlebell swings 3 x 15",
                "Push press 3 x 6"
            ]
            sled = a
                ? [push(q(20, 5), 1.2) + " x 4, 2 min rest", pull(q(20, 5), 1.15) + " x 4, 2 min rest", "Heavier than race weight, to cover for slow race carpet"]
                : [carry(q(40, 10), extra: 8) + " x 4, 90 s rest", push(q(25, 5), 1.0) + " x 3, 90 s rest", "Dead hang 3 x \(q(40, 5)) s"]
            why = "Build phase keeps the lifts heavy but adds overload on the sleds and carries. Gym turf is usually faster than race carpet, so training above race weight closes the gap."
        case .specific:
            title = "Strength Endurance: Race Weights"
            lifts = [
                (a ? "Back squat" : "Trap-bar deadlift") + " 3 x 5, moderate, crisp reps",
                lunge(q(30, 5)) + " x 3, 90 s rest",
                wb(n(25)) + " x 3, 60 s rest",
                "Hand-release push-ups 3 x \(n(12))"
            ]
            sled = [push(q(25, 5)) + " x 4, 90 s rest", pull(q(25, 5)) + " x 4, 90 s rest", carry(q(100, 25)) + " x 2, unbroken"]
            why = "Lifting volume drops so station quality can rise. Everything is now at race weight with short rests, the way you will meet it on the day."
        default:
            title = "Strength: Taper Tune-up"
            lifts = ["Back squat 2 x 5 at about 70% of recent working weight", "Romanian deadlift 2 x 6, light", "Pull-ups or pull-downs 2 x 6"]
            sled = [push(25) + " x 2, full rest", pull(25) + " x 2, full rest", wb(15) + " x 2"]
            why = "Just enough load to keep your nervous system sharp. No grinding reps, nothing to failure."
        }
        return Draft(kind: .strength, title: title + deloadTag, summary: lifts.first.map { String($0.prefix(while: { $0 != "," })) + ", then sleds" } ?? "",
                     minutes: deload || phase == .taper ? 45 : 65, rpe: deload || phase == .taper ? 5 : 7,
                     blocks: [
                        gymWarmup,
                        WorkoutBlock("Lifts", format: deload ? "Drop the load 10-15% and stop well short of failure" : "Rest fully between heavy sets", lifts),
                        WorkoutBlock(phase == .build && !a ? "Carries and sled" : "Sled work", format: "Quality over speed", sled),
                        WorkoutBlock("Core", format: "3 rounds", ["Front plank 45 s", "Pallof press or dead bug x 10 per side", "Back extension x 12"]),
                        coolDown
                     ],
                     note: note(why))
    }

    // MARK: Hybrid slot: stations and compromised running

    func hybrid() -> Draft {
        if phase == .taper { return taperStations() }
        let threeDay = p.daysPerWeek <= 3
        switch phase {
        case .base:
            if threeDay && week % 2 == 0 { return condensedStrength() }
            return stations(inPhase)
        case .build:
            if threeDay && week % 3 == 0 { return condensedStrength() }
            return inPhase % 2 == 0 ? compromised(inPhase / 2) : stations(inPhase + 1)
        default:
            return inPhase % 3 == 2 ? stations(inPhase) : compromised(inPhase)
        }
    }

    private func condensedStrength() -> Draft {
        let s = strength()
        return Draft(kind: .strength, title: s.title, summary: s.summary, minutes: s.minutes, rpe: s.rpe, blocks: s.blocks,
                     note: (s.note ?? "") + " On three days a week this slot alternates between strength and station work.")
    }

    func stations(_ variant: Int) -> Draft {
        let v = deload ? 0 : variant % 6
        let heavy = phase != .base
        func make(_ title: String, _ summary: String, _ mins: Int, _ rpe: Int, _ format: String, _ items: [String], _ why: String, finisher: WorkoutBlock? = nil) -> Draft {
            var blocks = [gymWarmup, WorkoutBlock("Main set", format: format, items)]
            if let f = finisher { blocks.append(f) }
            blocks.append(coolDown)
            return Draft(kind: .stations, title: title + deloadTag, summary: summary, minutes: deload ? mins - 10 : mins, rpe: deload ? rpe - 1 : rpe, blocks: blocks, note: note(why))
        }
        switch v {
        case 0:
            let rounds = n(6)
            return make("Station EMOM", "\(rounds * 4) min rotating EMOM: erg, wall balls, burpees", 50, 6,
                        "Every minute on the minute for \(rounds * 4) min, rotating through 4 stations",
                        ["Minute 1: " + ski(150), "Minute 2: " + wb(15), "Minute 3: 6 burpee broad jumps", "Minute 4: rest",
                         "Each working minute should leave 15-20 s of rest. If not, trim the reps."],
                        "EMOMs teach you each station at a controlled dose, with enough rest to keep your technique clean.")
        case 1:
            let rounds = n(4)
            return make("Sled + Carry Rounds", "\(rounds) rounds: push, pull, carry", 50, 7,
                        "\(rounds) rounds, 90 s rest between rounds",
                        [push(25, heavy ? 1 : 0.8), pull(25, heavy ? 1 : 0.8), carry(100), "Walk briskly between stations as if you were in the Roxzone"],
                        "The sleds are where races are lost by people who have never felt race weight. Repetition here pays off more than anywhere else.")
        case 2:
            let reps = p.level == .beginner ? 10 : (p.level == .intermediate ? 12 : 15)
            return make("Wall Ball Builder", "10 min wall ball EMOM, then row and lunge rounds", 50, 6,
                        "Part A: 10 min EMOM. Part B: 3 rounds, 60 s rest.",
                        ["A. Every minute for 10 min: " + wb(reps), "B. 3 rounds: " + row(500) + " + " + lunge(q(20, 5)),
                         "Full depth, hit the target, every single rep"],
                        "100 wall balls come last, when you are most tired. Building volume in small unbroken sets is how you avoid long breaks on race day.")
        case 3:
            let wbReps = phase == .base ? n(50) : (phase == .build ? n(75) : 100)
            return make("Back-Half Chipper", "Row, carry, lunges, wall balls in race order", 50, 7,
                        "One time through for time, steady effort, record your total",
                        [row(1000), carry(200), lunge(phase == .base ? 50 : 100), wb(wbReps), "Plan your wall ball sets before you start and stick to them"],
                        "The back half of the race in order, without the runs. Compare your total time each time this comes round.")
        case 4:
            let reps = n(6)
            return make("Erg Intervals + Burpees", "\(reps) x 500 m erg at race effort, then burpee broad jumps", 50, 7,
                        "Alternate SkiErg and rower, 90 s rest between",
                        ["\(reps) x 500 m, alternating " + ski(500) + " and " + row(500), "Target: your planned race split, no faster",
                         "Then 4 x " + bbj(20) + ", 60 s rest, same step-down, step-up rhythm every rep"],
                        "Holding an exact split on the ergs is a pacing skill. Most people go 5-10 seconds too fast in the first 300 m and pay for it.")
        default:
            let mins = q(20, 5)
            return make("Station AMRAP", "\(mins) min AMRAP: run, wall balls, ski, lunges", 50, 7,
                        "As many rounds as possible in \(mins) min at a sustainable effort",
                        ["200 m run", wb(10), ski(150), lunge(10), "Count rounds and try to beat it next time"],
                        "Continuous mixed work at a steady effort, close to how the middle of the race feels.")
        }
    }

    func compromised(_ variant: Int) -> Draft {
        let v = deload ? 0 : variant % 5
        func make(_ title: String, _ summary: String, _ format: String, _ items: [String], _ why: String) -> Draft {
            Draft(kind: .compromised, title: title + deloadTag, summary: summary, minutes: deload ? 45 : 60, rpe: deload ? 6 : 8,
                  blocks: [runWarmup, WorkoutBlock("Main set", format: format, items), coolDown], note: note(why))
        }
        switch v {
        case 0:
            let r = n(4)
            return make("Sled Sandwich", "\(r) rounds: 800 m run, sled push, sled pull",
                        "\(r) rounds, 2 min rest between rounds",
                        ["800 m at \(pace.raceText)", push(25), pull(25), "Start each run at an easy shuffle for 100 m, then build to pace"],
                        "Running straight off the sleds is the hardest transition in the race. Your legs come back after about 300 m; learn to trust that.")
        case 1:
            let r = n(5)
            return make("Wall Balls Into Runs", "\(r) rounds: \(n(20)) wall balls, 400 m run",
                        "\(r) rounds, 60 s rest between rounds",
                        [wb(n(20)), "400 m at \(pace.raceText) or slightly quicker", "Go straight from the last throw into the run, no pause"],
                        "Trains your breathing to settle while your quads are loaded, and makes the wall balls feel routine.")
        case 2:
            let r = n(4)
            return make("Lunge, Throw, Run", "\(r) rounds: 1 km, lunges, wall balls",
                        "\(r) rounds, 2 min rest between rounds",
                        ["1 km at \(pace.raceText)", lunge(q(25, 5)), wb(n(20)), "Keep the lunges continuous even if slow"],
                        "The last two stations with a race-pace kilometre in front. This is the part of the race where places change.")
        case 3:
            let r = n(4)
            return make("Erg Bricks", "\(r) rounds: ski, 1 km run, row",
                        "\(r) rounds, 90 s rest between rounds",
                        [ski(500), "1 km at \(pace.raceText)", row(500), "Ergs at planned race split, not faster"],
                        "Practises getting off an erg and finding run pace immediately, and treating the row as controlled recovery.")
        default:
            let r = n(6)
            return make("Roxzone Practice", "\(r) rounds: 600 m run with alternating burpees and carry",
                        "\(r) rounds, no rest: jog the transitions",
                        ["600 m at \(pace.raceText)", "Odd rounds: " + bbj(20), "Even rounds: " + carry(100), "Time your transitions; walk fast, never stand still"],
                        "No planned rest, just like the race. Smooth transitions are worth minutes and cost no fitness.")
        }
    }

    private func taperStations() -> Draft {
        Draft(kind: .stations, title: "Station Rehearsal", summary: "One short touch on every station at race weight", minutes: 40, rpe: 5,
              blocks: [
                gymWarmup,
                WorkoutBlock("Main set", format: "One time through, walking between stations. Smooth, not fast.", [
                    ski(300), push(25), pull(25), bbj(20), row(300), carry(100), lunge(25), wb(25),
                    "Rehearse your race cues at every station"
                ]),
                coolDown
              ],
              note: "A dress rehearsal for technique and confidence. If anything feels hard today, it is the taper talking; that passes by race day.")
    }

    // MARK: Simulations

    enum Sim { case halfFront, halfBack, full }

    func simulation(_ sim: Sim) -> Draft {
        let runLine = "1 km RUN at \(pace.raceText)"
        let front = [ski(1000), push(50), pull(50), bbj(80)]
        let back = [row(1000), carry(200), lunge(100), wb(100)]
        let stationsList: [String]
        let title: String
        let mins: Int
        let why: String
        switch sim {
        case .halfFront:
            stationsList = front; title = "Half Simulation: Stations 1-4"; mins = 60
            why = "The first half of the race at full distance and race weight. The lesson is restraint: finish knowing you could have carried on."
        case .halfBack:
            stationsList = back; title = "Half Simulation: Stations 5-8"; mins = 60
            why = "The back half at full distance. Use it to settle your wall ball set plan and your pacing on the lunges."
        case .full:
            stationsList = front + back; title = "Full Race Simulation"; mins = 110
            why = "The complete race, once, about three weeks out. Treat it as a test of pacing, fuelling and kit, not a maximum effort. Take the next day off and expect to need most of a week to absorb it."
        }
        var items: [String] = []
        for s in stationsList {
            items.append(runLine)
            items.append(s)
        }
        items.append("Log every split in the session notes. They become your race plan.")
        return Draft(kind: .simulation, title: title, summary: "\(stationsList.count) x (1 km run + station) at race weight", minutes: mins, rpe: sim == .full ? 9 : 8,
                     blocks: [
                        runWarmup,
                        WorkoutBlock("Simulation", format: "Continuous, race order, race weights. Set the stations up before you start.", items),
                        WorkoutBlock("Cool-down", format: "10 minutes", ["Walk 5-10 min", "Eat and drink within the hour", "Write down what you would change"])
                     ],
                     note: why)
    }

    // MARK: Race week

    func raceWeekDay(_ toRace: Int) -> Draft {
        switch toRace {
        case 0: return raceDay()
        case 1:
            return Draft(kind: .rest, title: "Day Before: Rest + Prep", summary: "No training. Pack, eat, sleep.", minutes: 0, rpe: 0,
                         blocks: [
                            WorkoutBlock("Checklist", format: nil, [
                                "Pack: race shoes you have trained in, kit, ID and ticket, gels, water",
                                "Check your wave start time and travel plan; arrive about 90 min early",
                                "Carb-focused meals today, familiar food only, low fibre in the evening",
                                "Read your pacing card in the Race tab once more",
                                "Optional: 15 min walk and 5 min light mobility"
                            ])
                         ],
                         note: "Nothing you do today adds fitness. Feet up, lights out early.")
        case 2:
            return Draft(kind: .recovery, title: "Primer", summary: "20 min shakeout with a few race-pace pickups", minutes: 25, rpe: 3,
                         blocks: [WorkoutBlock("Main set", format: "Short and snappy", [
                            "12 min easy jog at \(pace.easyText)",
                            "3 x 60 s at race pace \(pace.raceText), 90 s walk between",
                            wb(10) + ", " + ski(200) + ", easy",
                            "5 min mobility"
                         ])],
                         note: "A short primer keeps your legs feeling springy. Finish wanting more.")
        case 3:
            return Draft(kind: .easyRun, title: "Easy Run + Strides", summary: "25 min easy, 4 strides", minutes: 30, rpe: 3,
                         blocks: [WorkoutBlock("Main set", format: "Zone 2", ["25 min at \(pace.easyText)", "4 x 20 s strides, full recovery"])],
                         note: "Keep the routine, drop the load. Sleep is this week's most important session.")
        case 5:
            return Draft(kind: .intervals, title: "Last Sharpener", summary: "3 x 1 km at race pace with light stations", minutes: 40, rpe: 6,
                         blocks: [
                            runWarmup,
                            WorkoutBlock("Main set", format: "3 rounds, 2 min rest. Controlled, not hard.", [
                                "1 km at \(pace.raceText)", "Round 1: " + push(25), "Round 2: " + bbj(20), "Round 3: " + wb(25)
                            ]),
                            coolDown
                         ],
                         note: "The last session with any bite, at least five days out so it is fully absorbed by the start line.")
        default:
            return rest("Race week. Rest days are part of the plan: stay off your feet, hydrate and keep meals regular.")
        }
    }

    func raceDay() -> Draft {
        let s = spec
        return Draft(kind: .race, title: "RACE DAY", summary: "8 x 1 km + 8 stations. Run your plan.", minutes: 90, rpe: 10,
                     blocks: [
                        WorkoutBlock("Before", format: "Arrive about 90 min before your wave", [
                            "Full familiar meal 2-3 h before the start; banana or gel about 1 h out",
                            "Walk the venue: find the Roxzone entry and exit and the station order",
                            "Warm-up, starting 30-40 min out: 8 min easy jog, mobility, 4 strides, 2 min on an erg, 10 wall balls",
                            "Keep the gap between warm-up and start short"
                        ]),
                        WorkoutBlock("Run plan", format: "Target \(pace.raceText)", [
                            "Run 1: 10-15 s per km slower than target. Everyone else will sprint. Let them go.",
                            "Runs 2-4: settle on target pace. The first 200 m after each sled feels awful and passes.",
                            "Runs 5-7: hold pace. This is where even pacing overtakes people.",
                            "Run 8: empty the tank, you only need legs for the wall balls",
                            "Count your laps out loud on every run"
                        ]),
                        WorkoutBlock("Station plan", format: "Race weights for your division", [
                            "SkiErg 1000 m: steady, about 5 s per 500 m slower than fresh",
                            "Sled push 50 m @ \(Fmt.kg(s.sledPush)): low, short steps, rest only at lane ends",
                            "Sled pull 50 m @ \(Fmt.kg(s.sledPull)): legs and bodyweight, stay in the box",
                            "Burpee broad jumps 80 m: step down, step up, same jump every rep",
                            "Row 1000 m: long strokes, relax the grip, recover here",
                            "Farmers carry 200 m @ 2 x \(Fmt.kg(s.farmers)): tall and fast, unbroken",
                            "Sandbag lunges 100 m @ \(Fmt.kg(s.sandbag)): continuous, knee down every step",
                            "Wall balls 100 @ \(Fmt.kg(s.wallBall)): planned sets, break before you fail"
                        ]),
                        WorkoutBlock("After", format: nil, ["Keep walking for 10 min", "Carbs and protein within the hour", "Log your time in Progress"])
                     ],
                     note: "You have done the work. Start slower than feels right, stay calm in the Roxzone, and race the second half.")
    }

    func postRace() -> Draft {
        Draft(kind: .recovery, title: "Recovery Day", summary: "Easy walk and mobility", minutes: 30, rpe: 1,
              blocks: [WorkoutBlock("Optional", format: nil, ["20-30 min easy walk", "10 min gentle mobility", "Write down what went well and what you would change"])],
              note: "Well raced. Take a full easy week before you think about training again.")
    }
}
