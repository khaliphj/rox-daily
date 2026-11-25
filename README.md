# Rox Daily

A personal iPhone app that shows one HYROX workout per day, from today to race day.

## Install on your iPhone

Needs a Mac with Xcode 16 or newer and an iPhone on iOS 17 or newer.

### Easiest: Xcode over USB

1. Unzip, then double-click `RoxDaily.xcodeproj`.
2. In Xcode: click the blue **RoxDaily** project icon, then the **RoxDaily** target, then **Signing & Capabilities**, and pick your Apple ID under **Team**.
3. Plug in your iPhone, choose it in the device menu at the top, and press **Run** (the play button).
4. First time only, on the phone: **Settings > General > VPN & Device Management**, trust your developer certificate. If asked, also turn on **Developer Mode** under **Settings > Privacy & Security**.

### One command (after Xcode has signed it once)

```bash
./install.sh
```

Builds and installs to the iPhone plugged in over USB. If it cannot find your signing team it opens Xcode instead.

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
