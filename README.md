# Rox Daily

A personal iPhone app that shows one HYROX workout per day, from today to race day.

## Install on your iPhone

Needs a Mac with Xcode 16 or newer and an iPhone on iOS 17 or newer.

### Easiest: double-click

1. Plug your iPhone into the Mac with a cable, unlock it, and tap **Trust**.
2. Double-click **Install on iPhone.command** in this folder.

It finds your iPhone and Apple ID team, builds the app, installs it and opens it. If anything is missing it opens Xcode and tells you what to do. The first time, macOS may ask you to confirm opening the file (right-click it and choose **Open**), and the phone may ask you to trust your developer certificate under **Settings > General > VPN & Device Management**.

### Or in Xcode

1. Double-click `RoxDaily.xcodeproj`.
2. Click the blue **RoxDaily** project icon, then the **RoxDaily** target, then **Signing & Capabilities**, and pick your Apple ID under **Team**.
3. Choose your iPhone in the device menu at the top and press **Run**.

With a free Apple ID the app must be re-installed every 7 days. A paid developer account extends that to a year.

## What it does

- **Today**: the day's session with warm-up, main set and cool-down, tick-off steps, a stopwatch, and a log for effort and notes.
- **Plan**: every week to race day, in phases (Base, Build, Race Specific, Taper, Race Week) with a lighter week every fourth. A **For Time** tab holds stand-alone run-and-station workouts.
- **News**: live HYROX headlines for your city, events, workouts and general news, plus links to the race finder and nearby training clubs.
- **Race**: weights for your division, a guide to each station, and a pacing card for your target time.
- **Progress**: sessions completed, streak, hours trained, and benchmark results.

Paces come from your 5K time and loads from your division. Update the 5K time in Settings as you get fitter.

## Layout

- `RoxDaily/Core`: models, plan generator, race data, news feed reader. No UI code.
- `RoxDaily/Views`: SwiftUI screens.
- `RoxDaily/Store.swift`: saved profile, logs and reminders.
