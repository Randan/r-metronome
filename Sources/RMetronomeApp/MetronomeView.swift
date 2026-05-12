import RMetronomeCore
import SwiftUI

struct MetronomeView: View {
    @State private var viewModel = MetronomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                tempoControl
                presetControl
                meterControls
                groupingControl
                patternControl
                subdivisionControl
                practiceControl
                tempoRampControl
                polyrhythmControl
                mixerControl
                deviceControl
                transport
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { viewModel.refreshDevices() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("r-metronome")
                    .font(.system(size: 28, weight: .semibold))
                Text(viewModel.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(viewModel.isPlaying ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 12, height: 12)
                .accessibilityLabel(viewModel.isPlaying ? "Playing" : "Stopped")
        }
    }

    private var tempoControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(viewModel.bpm.rounded()))")
                    .font(.system(size: 64, weight: .medium, design: .rounded))
                    .monospacedDigit()
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
        }
    }

    private var meterControls: some View {
        HStack(spacing: 16) {
            LabeledContent("Beats") {
                Stepper(value: $viewModel.beatsPerMeasure, in: 1...16, step: 1) {
                    Text("\(viewModel.beatsPerMeasure)")
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
                .onChange(of: viewModel.beatsPerMeasure) { _, _ in viewModel.applyChangedTiming() }
            }

            LabeledContent("Unit") {
                Picker("", selection: $viewModel.beatUnit) {
                    Text("2").tag(2)
                    Text("4").tag(4)
                    Text("8").tag(8)
                    Text("16").tag(16)
                }
                .labelsHidden()
                .frame(width: 86)
                .onChange(of: viewModel.beatUnit) { _, _ in viewModel.applyChangedTiming() }
            }
        }
    }

    private var presetControl: some View {
        HStack(spacing: 8) {
            ForEach(MetronomePreset.allCases, id: \.rawValue) { preset in
                Button(preset.title) {
                    viewModel.applyPreset(preset)
                }
            }
            Spacer()
        }
    }

    private var subdivisionControl: some View {
        Picker("Subdivision", selection: $viewModel.subdivision) {
            Text("None").tag(Subdivision.none)
            Text("Eighths").tag(Subdivision.eighths)
            Text("Triplets").tag(Subdivision.triplets)
            Text("Sixteenths").tag(Subdivision.sixteenths)
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.subdivision) { _, _ in viewModel.applyChangedTiming() }
    }

    private var groupingControl: some View {
        LabeledContent("Grouping") {
            TextField("3+2+2", text: $viewModel.groupingText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
                .onSubmit { viewModel.applyGroupingText() }
                .onChange(of: viewModel.groupingText) { _, _ in
                    guard viewModel.groupingText.isEmpty else { return }
                    viewModel.applyChangedTiming()
                }
        }
    }

    private var patternControl: some View {
        LabeledContent("Pattern") {
            TextField("A n n x", text: $viewModel.patternText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
                .onSubmit { viewModel.applyPatternText() }
                .onChange(of: viewModel.patternText) { _, _ in
                    guard viewModel.patternText.isEmpty else { return }
                    viewModel.applyChangedTiming()
                }
        }
    }

    private var practiceControl: some View {
        Toggle("Mute every other measure", isOn: $viewModel.muteEveryOtherMeasure)
            .toggleStyle(.checkbox)
            .onChange(of: viewModel.muteEveryOtherMeasure) { _, _ in viewModel.applyChangedTiming() }
    }

    private var tempoRampControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Tempo ramp", isOn: $viewModel.tempoRampEnabled)
                .toggleStyle(.checkbox)
                .onChange(of: viewModel.tempoRampEnabled) { _, _ in viewModel.applyChangedTiming() }

            HStack(spacing: 16) {
                LabeledContent("Step") {
                    Stepper(value: $viewModel.rampStep, in: -20...20, step: 1) {
                        Text("\(Int(viewModel.rampStep))")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                    .onChange(of: viewModel.rampStep) { _, _ in viewModel.applyChangedTiming() }
                }

                LabeledContent("Every") {
                    Stepper(value: $viewModel.rampEveryMeasures, in: 1...32, step: 1) {
                        Text("\(viewModel.rampEveryMeasures)")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                    .onChange(of: viewModel.rampEveryMeasures) { _, _ in viewModel.applyChangedTiming() }
                }

                LabeledContent("Max") {
                    Stepper(value: $viewModel.rampMaximumBPM, in: 20...300, step: 1) {
                        Text("\(Int(viewModel.rampMaximumBPM))")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    .onChange(of: viewModel.rampMaximumBPM) { _, _ in viewModel.applyChangedTiming() }
                }
            }
            .disabled(!viewModel.tempoRampEnabled)
            .foregroundStyle(viewModel.tempoRampEnabled ? .primary : .secondary)
        }
    }

    private var polyrhythmControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Polyrhythm", isOn: $viewModel.polyrhythmEnabled)
                .toggleStyle(.checkbox)
                .onChange(of: viewModel.polyrhythmEnabled) { _, _ in viewModel.applyChangedTiming() }

            HStack(spacing: 16) {
                LabeledContent("BPM") {
                    Stepper(value: $viewModel.polyrhythmBPM, in: 20...300, step: 1) {
                        Text("\(Int(viewModel.polyrhythmBPM))")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                    .onChange(of: viewModel.polyrhythmBPM) { _, _ in viewModel.applyChangedTiming() }
                }

                LabeledContent("Beats") {
                    Stepper(value: $viewModel.polyrhythmBeats, in: 1...16, step: 1) {
                        Text("\(viewModel.polyrhythmBeats)")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                    .onChange(of: viewModel.polyrhythmBeats) { _, _ in viewModel.applyChangedTiming() }
                }
            }
            .disabled(!viewModel.polyrhythmEnabled)
            .foregroundStyle(viewModel.polyrhythmEnabled ? .primary : .secondary)
        }
    }


    private var mixerControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mixer")
                .font(.headline)

            gainSlider("Accent", value: $viewModel.accentGain)
            gainSlider("Normal", value: $viewModel.normalGain)
            gainSlider("Subdivision", value: $viewModel.subdivisionGain)
            gainSlider("Polyrhythm", value: $viewModel.polyrhythmGain)
        }
    }

    private func gainSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 86, alignment: .leading)
            Slider(value: value, in: 0...1, step: 0.05)
                .onChange(of: value.wrappedValue) { _, _ in viewModel.applyChangedTiming() }
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var deviceControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output devices")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    viewModel.refreshDevices()
                }
            }

            if viewModel.outputDevices.isEmpty {
                Text("No output devices")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.outputDevices, id: \.self) { device in
                    Text(device)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var transport: some View {
        HStack {
            Button {
                viewModel.togglePlayback()
            } label: {
                Label(viewModel.isPlaying ? "Stop" : "Play", systemImage: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .frame(minWidth: 110)
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
                viewModel.applyChangedTiming()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.large)

            Spacer()
        }
    }
}

#Preview {
    MetronomeView()
        .frame(width: 520, height: 460)
}
