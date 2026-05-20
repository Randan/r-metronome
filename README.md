# r-metronome

Sample-clock driven metronome core for macOS / Swift.

The core rule is that musical timing is calculated in audio sample frames, not by `Timer`, `DispatchQueue`, or display callbacks. UI state is converted into immutable snapshots and consumed by the scheduler/audio layer.

## Layers

- UI: SwiftUI/AppKit views and controls.
- State: immutable `MetronomeState` snapshots.
- Transport/Scheduler: sample-time event generation.
- Audio Engine: AVAudioEngine/player-node buffer scheduling.
- Device/Routing: CoreAudio device and channel metadata.

## Current Scaffold

- `MetronomeScheduler`: derives event sample times from absolute beat indexes to avoid accumulated rounding drift.
- `Pattern`: beat/accent/mute grid plus grouping metadata.
- `ClickGenerator`: preloads click buffers for accent, normal, and subdivision layers.
- `AudioEngineManager`: owns AVAudioEngine graph and schedules prebuilt buffers at exact sample times.
- `MetronomeTransport`: keeps a short lookahead window filled with sample-timed click events.
- `OutputRouting`: declares layer-to-channel-pair intent for multi-output routing.
- `OutputDeviceManager`: reads CoreAudio output devices and channel counts.
- `StateSnapshotStore`: double-buffer style state handoff for applying UI changes at musical boundaries.

## Run

```bash
swift run r-metronome --bpm 120 --duration 10
```

With subdivisions:

```bash
swift run r-metronome --bpm 90 --beats 7 --subdivision eighths --duration 15
```

With grouped accents:

```bash
swift run r-metronome --bpm 120 --grouping 3+2+2 --duration 15
```

With a custom beat grid:

```bash
swift run r-metronome --bpm 120 --pattern "A n n x" --duration 15
```

With a preset:

```bash
swift run r-metronome --preset 3+2+2 --duration 15
```

Inspect scheduled events without audio:

```bash
swift run r-metronome --dry-run --duration 4
```

Save or load a portable session JSON:

```bash
swift run r-metronome --preset clave --poly-bpm 180 --save-config clave-session.json --dry-run
swift run r-metronome --config clave-session.json --duration 20
```

With mute trainer:

```bash
swift run r-metronome --bpm 100 --mute-every-other --duration 20
```

With tempo ramp:

```bash
swift run r-metronome --bpm 100 --ramp-step 5 --ramp-every 4 --ramp-max 140 --duration 60
```

With a secondary polyrhythm layer:

```bash
swift run r-metronome --bpm 120 --poly-bpm 180 --poly-beats 3 --duration 20
```

With true 3-over-4 polyrhythm:

```bash
swift run r-metronome --bpm 120 --poly-over 3 --duration 20
```

With mixer gains:

```bash
swift run r-metronome --accent-gain 1 --normal-gain 0.7 --subdivision-gain 0.35 --subdivision eighths
```

List CoreAudio output devices:

```bash
swift run r-metronome --list-devices
```

Run the SwiftUI macOS app:

```bash
swift run r-metronome-app
```

The app includes pattern presets, custom `A n x` beat grids, per-layer mixer gains, output device visibility, tap tempo, mute trainer, tempo ramp, and polyrhythm controls.

Build a release `.app` bundle and DMG:

```bash
make dmg
```

The generated package is written to `dist/r-metronome.dmg`.

## Timing Contract

```swift
samplesPerBeat = sampleRate * 60 / bpm
eventSample = startSampleTime + round(beatIndex * samplesPerBeat)
```

Events are calculated from the original beat index, not by repeatedly adding a rounded interval.
