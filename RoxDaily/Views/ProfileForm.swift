import SwiftUI

/// Shared editor used by onboarding and settings.
struct ProfileForm: View {
    @Binding var profile: Profile

    private var minutes: Binding<Int> {
        Binding(get: { profile.fiveKSeconds / 60 }, set: { profile.fiveKSeconds = $0 * 60 + profile.fiveKSeconds % 60 })
    }
    private var seconds: Binding<Int> {
        Binding(get: { profile.fiveKSeconds % 60 }, set: { profile.fiveKSeconds = (profile.fiveKSeconds / 60) * 60 + $0 })
    }

    var body: some View {
        Section {
            DatePicker("Race day", selection: $profile.raceDate, in: Cal.day(Date())...Cal.add(730, to: Date()), displayedComponents: .date)
            TextField("Home city", text: $profile.city)
            Picker("Division", selection: $profile.division) {
                ForEach(Division.allCases) { Text($0.title).tag($0) }
            }
        } header: {
            Text("Your race")
        } footer: {
            Text("HYROX Atlanta is listed for 23-25 April 2027. Set the exact day once you have your ticket. The city localises your news feed.")
        }

        Section {
            Picker("Level", selection: $profile.level) {
                ForEach(Level.allCases) { Text($0.title).tag($0) }
            }
            Stepper("Training days per week: \(profile.daysPerWeek)", value: $profile.daysPerWeek, in: 3...6)
        } header: {
            Text("Training")
        } footer: {
            Text(profile.level.blurb)
        }

        Section {
            HStack {
                Text("Current 5K time")
                Spacer()
                Picker("Minutes", selection: minutes) {
                    ForEach(14..<60, id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Picker("Seconds", selection: seconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        } header: {
            Text("Running")
        } footer: {
            Text("Every pace in the plan comes from this. A recent race or a hard solo effort is best; a rough guess is fine and you can update it any time.")
        }

        Section {
            Toggle("Sled", isOn: $profile.hasSled)
            Toggle("SkiErg", isOn: $profile.hasSkiErg)
            Toggle("Rower", isOn: $profile.hasRower)
            Toggle("Wall ball and target", isOn: $profile.hasWallBall)
        } header: {
            Text("Equipment at your gym")
        } footer: {
            Text("Anything switched off is replaced with the closest substitute in every workout.")
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var draft = Store.defaultProfile()
    @State private var started = false

    var body: some View {
        if started {
            NavigationStack {
                Form {
                    ProfileForm(profile: $draft)
                    Section {
                        Button("Build my plan") {
                            var p = draft
                            p.planStart = Cal.day(Date())
                            store.setProfile(p)
                        }
                        .buttonStyle(PillButtonStyle())
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .navigationTitle("Set up your plan")
            }
        } else {
            splash
        }
    }

    private var splash: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 88, height: 88)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("Rox Daily").font(.system(size: 40, weight: .bold)).padding(.top, 8)
            Text("One HYROX workout a day,\nfrom today to your start line.")
                .font(.body).multilineTextAlignment(.center).opacity(0.9)
            Spacer()
            Button("Get started") { withAnimation { started = true } }
                .buttonStyle(PillButtonStyle(fill: .white, text: Theme.accent))
        }
        .foregroundStyle(Color.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Theme.accent, Color(red: 0.30, green: 0.62, blue: 1.0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Store.defaultProfile()

    var body: some View {
        NavigationStack {
            Form {
                ProfileForm(profile: $draft)
                Section {
                    Toggle("Daily reminder", isOn: $store.reminderOn)
                    if store.reminderOn {
                        Picker("Time", selection: $store.reminderHour) {
                            ForEach(4..<23, id: \.self) { Text(String(format: "%d:00", $0)).tag($0) }
                        }
                    }
                } header: {
                    Text("Reminders")
                }
                Section {
                    Button("Restart plan from today", role: .destructive) {
                        draft.planStart = Cal.day(Date())
                        store.setProfile(draft)
                        dismiss()
                    }
                } footer: {
                    Text("Rebuilds the phases from today to race day. Your completed sessions are kept.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.setProfile(draft); dismiss() }
                }
            }
            .onAppear { if let p = store.profile { draft = p } }
        }
    }
}
