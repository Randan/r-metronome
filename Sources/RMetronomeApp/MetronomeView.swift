import RMetronomeCore
import SwiftUI

struct MetronomeView: View {
    @State private var viewModel = MetronomeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    tempoPanel
                    pendulumPanel
                    patternPanel
                    practicePanel
                    mixerPanel
                    outputPanel
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            transportBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { viewModel.refreshDevices() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("r-metronome")
                    .font(.system(size: 26, weight: .semibold))
                Text(viewModel.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusPill
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isPlaying ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 10, height: 10)
            Text(viewModel.isPlaying ? "Playing" : "Stopped")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var tempoPanel: some View {
        section("Tempo") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(Int(viewModel.bpm.rounded()))")
                        .font(.system(size: 72, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 142, alignment: .leading)
                    Text("BPM")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper("", value: $viewModel.bpm, in: 20...300, step: 1)
                        .labelsHidden()
                        .onChange(of: viewModel.bpm) { _, _ in viewModel.applyChangedTiming() }
                }

                Slider(value: $viewModel.bpm, in: 20...300, step: 1)
                    .onChange(of: viewModel.bpm) { _, _ in viewModel.applyChangedTiming() }

                HStack(spacing: 10) {
                    ForEach(MetronomePreset.allCases, id: \.rawValue) { preset in
                        Button(preset.title) {
                            viewModel.applyPreset(preset)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var pendulumPanel: some View {
        section("Pendulum") {
            PendulumIndicator(bpm: viewModel.bpm, isPlaying: viewModel.isPlaying)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
        }
    }

    private var patternPanel: some View {
        section("Pattern") {
            VStack(spacing: 12) {
                controlRow("Meter") {
                    HStack(spacing: 12) {
                        Stepper(value: $viewModel.beatsPerMeasure, in: 1...16, step: 1) {
                            Text("\(viewModel.beatsPerMeasure)")
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                        }
                        .onChange(of: viewModel.beatsPerMeasure) { _, _ in viewModel.applyChangedTiming() }

                        Picker("", selection: $viewModel.beatUnit) {
                            Text("2").tag(2)
                            Text("4").tag(4)
                            Text("8").tag(8)
                            Text("16").tag(16)
                        }
                        .labelsHidden()
                        .frame(width: 88)
                        .onChange(of: viewModel.beatUnit) { _, _ in viewModel.applyChangedTiming() }
                    }
                }

                controlRow("Grouping") {
                    TextField("3+2+2", text: $viewModel.groupingText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.applyGroupingText() }
                        .onChange(of: viewModel.groupingText) { _, _ in
                            guard viewModel.groupingText.isEmpty else { return }
                            viewModel.applyChangedTiming()
                        }
                }

                controlRow("Grid") {
                    TextField("A n n x", text: $viewModel.patternText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.applyPatternText() }
                        .onChange(of: viewModel.patternText) { _, _ in
                            guard viewModel.patternText.isEmpty else { return }
                            viewModel.applyChangedTiming()
                        }
                }

                controlRow("Subdivision") {
                    Picker("", selection: $viewModel.subdivision) {
                        Text("None").tag(Subdivision.none)
                        Text("Eighths").tag(Subdivision.eighths)
                        Text("Triplets").tag(Subdivision.triplets)
                        Text("Sixteenths").tag(Subdivision.sixteenths)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.subdivision) { _, _ in viewModel.applyChangedTiming() }
                }
            }
        }
    }

    private var practicePanel: some View {
        section("Practice") {
            VStack(spacing: 12) {
                controlRow("Mute") {
                    Toggle("Every other measure", isOn: $viewModel.muteEveryOtherMeasure)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.muteEveryOtherMeasure) { _, _ in viewModel.applyChangedTiming() }
                }

                controlRow("Ramp") {
                    Toggle("Enabled", isOn: $viewModel.tempoRampEnabled)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.tempoRampEnabled) { _, _ in viewModel.applyChangedTiming() }
                }

                HStack(spacing: 14) {
                    smallStepper("Step", value: $viewModel.rampStep, range: -20...20)
                    smallStepper("Every", value: $viewModel.rampEveryMeasures, range: 1...32)
                    smallStepper("Max", value: $viewModel.rampMaximumBPM, range: 20...300)
                }
                .padding(.leading, 116)
                .disabled(!viewModel.tempoRampEnabled)
                .foregroundStyle(viewModel.tempoRampEnabled ? .primary : .secondary)

                controlRow("Polyrhythm") {
                    Toggle("Enabled", isOn: $viewModel.polyrhythmEnabled)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.polyrhythmEnabled) { _, _ in viewModel.applyChangedTiming() }
                }

                HStack(spacing: 14) {
                    smallStepper("BPM", value: $viewModel.polyrhythmBPM, range: 20...300)
                    smallStepper("Beats", value: $viewModel.polyrhythmBeats, range: 1...16)
                    Spacer()
                }
                .padding(.leading, 116)
                .disabled(!viewModel.polyrhythmEnabled)
                .foregroundStyle(viewModel.polyrhythmEnabled ? .primary : .secondary)
            }
        }
    }

    private var mixerPanel: some View {
        section("Mixer") {
            VStack(spacing: 10) {
                gainSlider("Accent", value: $viewModel.accentGain)
                gainSlider("Normal", value: $viewModel.normalGain)
                gainSlider("Subdivision", value: $viewModel.subdivisionGain)
                gainSlider("Polyrhythm", value: $viewModel.polyrhythmGain)
            }
        }
    }

    private var outputPanel: some View {
        section("Output") {
            VStack(spacing: 12) {
                controlRow("Device") {
                    Picker("", selection: outputDeviceBinding) {
                        Text("System Default").tag(UInt32(0))
                        ForEach(viewModel.outputDevices) { device in
                            Text("\(device.name) (\(device.outputChannelCount) ch)").tag(device.id)
                        }
                    }
                    .labelsHidden()
                }

                controlRow("Channels") {
                    Picker("", selection: channelPairBinding) {
                        ForEach(viewModel.availableChannelPairs, id: \.self) { pair in
                            Text(pair.displayName).tag(pair)
                        }
                    }
                    .labelsHidden()
                    .disabled(viewModel.selectedDevice == nil)
                }

                HStack {
                    Spacer()
                    Button("Refresh Devices") {
                        viewModel.refreshDevices()
                    }
                }
            }
        }
    }

    private var transportBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.togglePlayback()
            } label: {
                Label(viewModel.isPlaying ? "Stop" : "Play", systemImage: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                viewModel.tapTempo()
            } label: {
                Label("Tap", systemImage: "hand.tap.fill")
            }
            .controlSize(.large)

            Button {
                reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.large)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var outputDeviceBinding: Binding<UInt32> {
        Binding {
            viewModel.selectedOutputDeviceID ?? 0
        } set: { id in
            viewModel.selectOutputDevice(id == 0 ? nil : id)
        }
    }

    private var channelPairBinding: Binding<ChannelPair> {
        Binding {
            viewModel.selectedChannelPair
        } set: { pair in
            viewModel.selectChannelPair(pair)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func controlRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 102, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func gainSlider(_ title: String, value: Binding<Double>) -> some View {
        controlRow(title) {
            HStack {
                Slider(value: value, in: 0...1, step: 0.05)
                    .onChange(of: value.wrappedValue) { _, _ in viewModel.applyChangedTiming() }
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private func smallStepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            Stepper(value: value, in: range, step: 1) {
                Text("\(Int(value.wrappedValue))")
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
            .onChange(of: value.wrappedValue) { _, _ in viewModel.applyChangedTiming() }
        }
    }

    private func smallStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        LabeledContent(title) {
            Stepper(value: value, in: range, step: 1) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }
            .onChange(of: value.wrappedValue) { _, _ in viewModel.applyChangedTiming() }
        }
    }

    private func reset() {
        viewModel.bpm = 120
        viewModel.beatsPerMeasure = 4
        viewModel.beatUnit = 4
        viewModel.groupingText = ""
        viewModel.patternText = ""
        viewModel.subdivision = .none
        viewModel.muteEveryOtherMeasure = false
        viewModel.tempoRampEnabled = false
        viewModel.rampStep = 5
        viewModel.rampEveryMeasures = 4
        viewModel.rampMaximumBPM = 180
        viewModel.polyrhythmEnabled = false
        viewModel.polyrhythmBPM = 180
        viewModel.polyrhythmBeats = 3
        viewModel.accentGain = 1.0
        viewModel.normalGain = 0.8
        viewModel.subdivisionGain = 0.6
        viewModel.polyrhythmGain = 0.7
        viewModel.selectOutputDevice(nil)
        viewModel.applyChangedTiming()
    }
}

private struct PendulumIndicator: View {
    var bpm: Double
    var isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let beatDuration = 60.0 / max(bpm, 1)
            let phase = isPlaying ? timeline.date.timeIntervalSinceReferenceDate / beatDuration : 0
            let swing = sin(phase * .pi * 2.0)
            let flash = isPlaying && abs(swing) > 0.94

            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 3, height: 68)
                    .rotationEffect(.degrees(swing * 28), anchor: .top)
                    .animation(.linear(duration: 0.03), value: swing)

                Circle()
                    .fill(flash ? Color.accentColor : Color.secondary.opacity(0.42))
                    .frame(width: 18, height: 18)
                    .offset(x: swing * 96, y: 62)
                    .shadow(color: flash ? Color.accentColor.opacity(0.55) : .clear, radius: 10)

                HStack {
                    Circle().fill(Color.secondary.opacity(0.25)).frame(width: 8, height: 8)
                    Spacer()
                    Circle().fill(Color.secondary.opacity(0.25)).frame(width: 8, height: 8)
                }
                .padding(.horizontal, 72)
                .offset(y: 68)
            }
        }
    }
}

#Preview {
    MetronomeView()
        .frame(width: 640, height: 760)
}
