import Foundation
import Observation
import RMetronomeCore

@Observable
@MainActor
final class MetronomeViewModel {
    var bpm: Double = 120
    var beatsPerMeasure: Int = 4
    var beatUnit: Int = 4
    var groupingText = ""
    var patternText = ""
    var subdivision: Subdivision = .none
    var muteEveryOtherMeasure = false
    var tempoRampEnabled = false
    var rampStep: Double = 5
    var rampEveryMeasures: Int = 4
    var rampMaximumBPM: Double = 180
    var polyrhythmEnabled = false
    var polyrhythmBPM: Double = 180
    var polyrhythmBeats: Int = 3
    var accentGain: Double = 1.0
    var normalGain: Double = 0.8
    var subdivisionGain: Double = 0.6
    var polyrhythmGain: Double = 0.7
    var outputDevices: [AudioOutputDevice] = []
    var selectedOutputDeviceID: UInt32?
    var selectedChannelPair = ChannelPair.stereoMain
    var isPlaying = false
    var status = "Ready"

    private let transport = MetronomeTransport()
    private var tapTimes: [Date] = []
    private let settingsKey = "r-metronome.settings.v1"

    init() {
        loadSettings()
    }

    func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func start() {
        stop()

        do {
            saveSettings()
            try transport.start(state: try makeState(isPlaying: true))
            isPlaying = true
            status = "Playing \(Int(bpm)) BPM"
        } catch {
            isPlaying = false
            status = "Audio error: \(error.localizedDescription)"
        }
    }

    func stop() {
        transport.stop()
        isPlaying = false
        status = "Stopped"
    }

    func applyChangedTiming() {
        saveSettings()
        guard isPlaying else { return }
        do {
            transport.update(state: try makeState(isPlaying: true))
            status = "Playing \(Int(bpm)) BPM"
        } catch {
            status = "Pattern error: \(error.localizedDescription)"
        }
    }

    func applyGroupingText() {
        if let grouping = try? Pattern.parseGrouping(groupingText), !grouping.isEmpty {
            beatsPerMeasure = grouping.reduce(0, +)
            patternText = ""
        }
        applyChangedTiming()
    }

    func applyPatternText() {
        if let pattern = try? Pattern.parseBeatGrid(patternText) {
            beatsPerMeasure = pattern.beats.count
            groupingText = ""
        }
        applyChangedTiming()
    }

    func applyPreset(_ preset: MetronomePreset) {
        switch preset {
        case .fourFour:
            beatsPerMeasure = 4
            beatUnit = 4
            groupingText = ""
            patternText = ""
        case .sixEight:
            beatsPerMeasure = 6
            beatUnit = 8
            groupingText = "3+3"
            patternText = ""
        case .sevenEight:
            beatsPerMeasure = 7
            beatUnit = 8
            groupingText = "3+2+2"
            patternText = ""
        case .clave:
            beatsPerMeasure = 8
            beatUnit = 8
            groupingText = ""
            patternText = "A x n x n x A x"
        }
        applyChangedTiming()
    }

    func tapTempo() {
        let now = Date()
        tapTimes.append(now)
        tapTimes = tapTimes.suffix(6)

        guard tapTimes.count >= 2 else {
            status = "Tap again"
            return
        }

        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { newer, older in
            newer.timeIntervalSince(older)
        }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        guard average > 0 else { return }

        bpm = min(max((60.0 / average).rounded(), 20), 300)
        applyChangedTiming()
    }

    func refreshDevices() {
        do {
            outputDevices = try OutputDeviceManager.outputDevices()
            if let selectedOutputDeviceID, !outputDevices.contains(where: { $0.id == selectedOutputDeviceID }) {
                self.selectedOutputDeviceID = nil
                selectedChannelPair = .stereoMain
            }
            if let selectedDevice, !selectedDevice.channelPairs.contains(selectedChannelPair) {
                selectedChannelPair = selectedDevice.channelPairs.first ?? .stereoMain
            }
        } catch {
            outputDevices = []
            status = "Device query failed"
        }
    }

    var selectedDevice: AudioOutputDevice? {
        guard let selectedOutputDeviceID else { return nil }
        return outputDevices.first { $0.id == selectedOutputDeviceID }
    }

    var availableChannelPairs: [ChannelPair] {
        selectedDevice?.channelPairs ?? [.stereoMain]
    }

    func selectOutputDevice(_ deviceID: UInt32?) {
        selectedOutputDeviceID = deviceID
        if let selectedDevice {
            selectedChannelPair = selectedDevice.channelPairs.first ?? .stereoMain
        } else {
            selectedChannelPair = .stereoMain
        }
        applyChangedOutput()
    }

    func selectChannelPair(_ channelPair: ChannelPair) {
        selectedChannelPair = channelPair
        applyChangedOutput()
    }

    private func applyChangedOutput() {
        saveSettings()
        guard isPlaying else { return }
        start()
    }

    private func loadSettings() {
        guard
            let data = UserDefaults.standard.data(forKey: settingsKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return
        }

        bpm = settings.bpm
        beatsPerMeasure = settings.beatsPerMeasure
        beatUnit = settings.beatUnit
        groupingText = settings.groupingText
        patternText = settings.patternText
        subdivision = settings.subdivision
        muteEveryOtherMeasure = settings.muteEveryOtherMeasure
        tempoRampEnabled = settings.tempoRampEnabled
        rampStep = settings.rampStep
        rampEveryMeasures = settings.rampEveryMeasures
        rampMaximumBPM = settings.rampMaximumBPM
        polyrhythmEnabled = settings.polyrhythmEnabled
        polyrhythmBPM = settings.polyrhythmBPM
        polyrhythmBeats = settings.polyrhythmBeats
        accentGain = settings.accentGain
        normalGain = settings.normalGain
        subdivisionGain = settings.subdivisionGain
        polyrhythmGain = settings.polyrhythmGain
        selectedOutputDeviceID = settings.selectedOutputDeviceID
        selectedChannelPair = settings.selectedChannelPair ?? .stereoMain
    }

    private func saveSettings() {
        let settings = AppSettings(
            bpm: bpm,
            beatsPerMeasure: beatsPerMeasure,
            beatUnit: beatUnit,
            groupingText: groupingText,
            patternText: patternText,
            subdivision: subdivision,
            muteEveryOtherMeasure: muteEveryOtherMeasure,
            tempoRampEnabled: tempoRampEnabled,
            rampStep: rampStep,
            rampEveryMeasures: rampEveryMeasures,
            rampMaximumBPM: rampMaximumBPM,
            polyrhythmEnabled: polyrhythmEnabled,
            polyrhythmBPM: polyrhythmBPM,
            polyrhythmBeats: polyrhythmBeats,
            accentGain: accentGain,
            normalGain: normalGain,
            subdivisionGain: subdivisionGain,
            polyrhythmGain: polyrhythmGain,
            selectedOutputDeviceID: selectedOutputDeviceID,
            selectedChannelPair: selectedChannelPair
        )

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func makePattern() throws -> Pattern {
        let trimmedPattern = patternText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPattern.isEmpty {
            return try Pattern.parseBeatGrid(trimmedPattern)
        }

        let trimmedGrouping = groupingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedGrouping.isEmpty {
            return Pattern.regular(beatsPerMeasure: beatsPerMeasure)
        }
        return try Pattern.grouped(Pattern.parseGrouping(trimmedGrouping))
    }

    private func makeState(isPlaying: Bool) throws -> MetronomeState {
        let pattern = try makePattern()
        return MetronomeState(
            bpm: bpm,
            timeSignature: TimeSignature(beatsPerMeasure: pattern.beats.count, beatUnit: beatUnit),
            pattern: pattern,
            subdivision: subdivision,
            muteTrainer: muteEveryOtherMeasure ? .everyOtherMeasure : nil,
            tempoRamp: tempoRampEnabled ? TempoRamp(
                bpmStep: rampStep,
                everyMeasures: rampEveryMeasures,
                maximumBPM: rampMaximumBPM
            ) : nil,
            polyrhythm: polyrhythmEnabled ? .regular(
                bpm: polyrhythmBPM,
                beats: polyrhythmBeats
            ) : nil,
            layerGains: LayerGains(
                accent: Float(accentGain),
                normal: Float(normalGain),
                subdivision: Float(subdivisionGain),
                polyrhythm: Float(polyrhythmGain)
            ),
            outputSelection: AudioOutputSelection(
                deviceID: selectedOutputDeviceID,
                channelPair: selectedChannelPair
            ),
            isPlaying: isPlaying
        )
    }
}

private struct AppSettings: Codable {
    var bpm: Double
    var beatsPerMeasure: Int
    var beatUnit: Int
    var groupingText: String
    var patternText: String
    var subdivision: Subdivision
    var muteEveryOtherMeasure: Bool
    var tempoRampEnabled: Bool
    var rampStep: Double
    var rampEveryMeasures: Int
    var rampMaximumBPM: Double
    var polyrhythmEnabled: Bool
    var polyrhythmBPM: Double
    var polyrhythmBeats: Int
    var accentGain: Double
    var normalGain: Double
    var subdivisionGain: Double
    var polyrhythmGain: Double
    var selectedOutputDeviceID: UInt32?
    var selectedChannelPair: ChannelPair?
}
