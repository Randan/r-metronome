import Foundation
import RMetronomeCore

struct CLIOptions {
    var bpm: Double = 120
    var beatsPerMeasure: Int = 4
    var beatUnit: Int = 4
    var duration: Double = 10
    var sampleRate: Double = 48_000
    var subdivision: Subdivision = .none
    var grouping: [Int]?
    var patternText: String?
    var preset: MetronomePreset?
    var muteEveryOtherMeasure = false
    var rampStep: Double?
    var rampEveryMeasures = 4
    var rampMaximumBPM: Double?
    var polyrhythmBPM: Double?
    var polyrhythmBeats = 3
    var polyrhythmOverBeats: Int?
    var accentGain: Float = 1.0
    var normalGain: Float = 0.8
    var subdivisionGain: Float = 0.6
    var polyrhythmGain: Float = 0.7
    var listDevices = false
    var listPresets = false
    var dryRun = false
    var configPath: String?
    var saveConfigPath: String?
}

enum CLIError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidValue(String, String)

    var description: String {
        switch self {
        case let .missingValue(option):
            "Missing value for \(option)"
        case let .invalidValue(option, value):
            "Invalid value for \(option): \(value)"
        }
    }
}

@main
struct RMetronomeCLI {
    static func main() throws {
        do {
            let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
            if options.listDevices {
                try printDevices()
                return
            }
            if options.listPresets {
                printPresets()
                return
            }
            try run(options: options)
        } catch let error as CLIError {
            FileHandle.standardError.write(Data((error.description + "\n\n" + helpText()).utf8))
            Foundation.exit(64)
        }
    }

    private static func run(options: CLIOptions) throws {
        var state = try makeState(options: options)
        state.isPlaying = true

        if let saveConfigPath = options.saveConfigPath {
            try saveSession(state: state, path: saveConfigPath)
            print("saved session: \(saveConfigPath)")
        }

        if options.dryRun {
            printDryRun(state: state, sampleRate: options.sampleRate, duration: options.duration)
            return
        }

        let transport = MetronomeTransport(
            configuration: .init(sampleRate: options.sampleRate, lookaheadSeconds: 1.5, refillIntervalSeconds: 0.25)
        )
        try transport.start(state: state)

        let meterLabel = "\(state.timeSignature.beatsPerMeasure)/\(state.timeSignature.beatUnit)"
        let groupingLabel = state.pattern.grouping.isEmpty ? "" : " grouping \(state.pattern.grouping.map(String.init).joined(separator: "+")),"
        let muteLabel = options.muteEveryOtherMeasure ? " mute every other measure," : ""
        let rampLabel = options.rampStep.map { " ramp \($0 >= 0 ? "+" : "")\(String(format: "%.1f", $0)) BPM every \(options.rampEveryMeasures) measures," } ?? ""
        let polyLabel = options.polyrhythmOverBeats.map { " poly \($0) over \(state.timeSignature.beatsPerMeasure)," }
            ?? options.polyrhythmBPM.map { " poly \(Int($0.rounded())) BPM/\(options.polyrhythmBeats) beats," }
            ?? ""
        print("r-metronome: \(Int(state.bpm.rounded())) BPM, \(meterLabel),\(groupingLabel)\(muteLabel)\(rampLabel)\(polyLabel) \(String(format: "%.1f", options.duration))s")
        print("transport lookahead: 1.5s")

        Thread.sleep(forTimeInterval: options.duration + 0.2)
        transport.stop()
    }

    private static func printDevices() throws {
        let devices = try OutputDeviceManager.outputDevices()
        if devices.isEmpty {
            print("No output devices found.")
            return
        }

        for device in devices {
            print("\(device.id)\t\(device.outputChannelCount) ch\t\(device.name)")
        }
    }

    private static func printPresets() {
        for preset in MetronomePreset.allCases {
            print("\(preset.rawValue)\t\(preset.title)")
        }
    }

    private static func printDryRun(state: MetronomeState, sampleRate: Double, duration: Double) {
        let scheduler = MetronomeScheduler(sampleRate: sampleRate, startSampleTime: 0, state: state)
        let upperBound = Int64((duration * sampleRate).rounded(.up))
        let events = scheduler.events(from: 0, through: upperBound)

        print(state.summary)
        for event in events {
            let seconds = Double(event.sampleTime) / sampleRate
            print("\(event.sampleTime)\t\(String(format: "%.6f", seconds))s\tbeat \(event.beatIndex)\t\(event.layer)")
        }
    }

    private static func parseOptions(_ arguments: [String]) throws -> CLIOptions {
        var options = CLIOptions()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--help", "-h":
                print(helpText())
                Foundation.exit(0)
            case "--list-devices":
                options.listDevices = true
            case "--list-presets":
                options.listPresets = true
            case "--dry-run":
                options.dryRun = true
            case "--config":
                options.configPath = try readString(arguments, &index, option: argument)
            case "--save-config":
                options.saveConfigPath = try readString(arguments, &index, option: argument)
            case "--bpm":
                options.bpm = try readDouble(arguments, &index, option: argument)
            case "--duration":
                options.duration = try readDouble(arguments, &index, option: argument)
            case "--sample-rate":
                options.sampleRate = try readDouble(arguments, &index, option: argument)
            case "--beats":
                options.beatsPerMeasure = try readInt(arguments, &index, option: argument)
            case "--beat-unit":
                options.beatUnit = try readInt(arguments, &index, option: argument)
            case "--subdivision":
                let value = try readString(arguments, &index, option: argument)
                options.subdivision = try parseSubdivision(value, option: argument)
            case "--grouping":
                let value = try readString(arguments, &index, option: argument)
                options.grouping = try parseGrouping(value, option: argument)
            case "--pattern":
                options.patternText = try readString(arguments, &index, option: argument)
            case "--preset":
                let value = try readString(arguments, &index, option: argument)
                options.preset = try parsePreset(value, option: argument)
            case "--mute-every-other":
                options.muteEveryOtherMeasure = true
            case "--ramp-step":
                options.rampStep = try readDouble(arguments, &index, option: argument)
            case "--ramp-every":
                options.rampEveryMeasures = try readInt(arguments, &index, option: argument)
            case "--ramp-max":
                options.rampMaximumBPM = try readDouble(arguments, &index, option: argument)
            case "--poly-bpm":
                options.polyrhythmBPM = try readDouble(arguments, &index, option: argument)
            case "--poly-beats":
                options.polyrhythmBeats = try readInt(arguments, &index, option: argument)
            case "--poly-over":
                options.polyrhythmOverBeats = try readInt(arguments, &index, option: argument)
            case "--accent-gain":
                options.accentGain = try readFloat(arguments, &index, option: argument)
            case "--normal-gain":
                options.normalGain = try readFloat(arguments, &index, option: argument)
            case "--subdivision-gain":
                options.subdivisionGain = try readFloat(arguments, &index, option: argument)
            case "--poly-gain":
                options.polyrhythmGain = try readFloat(arguments, &index, option: argument)
            default:
                throw CLIError.invalidValue("argument", argument)
            }
            index += 1
        }

        guard options.bpm > 0 else { throw CLIError.invalidValue("--bpm", "\(options.bpm)") }
        guard options.duration > 0 else { throw CLIError.invalidValue("--duration", "\(options.duration)") }
        guard options.sampleRate > 0 else { throw CLIError.invalidValue("--sample-rate", "\(options.sampleRate)") }
        guard options.beatsPerMeasure > 0 else { throw CLIError.invalidValue("--beats", "\(options.beatsPerMeasure)") }
        guard options.beatUnit > 0 else { throw CLIError.invalidValue("--beat-unit", "\(options.beatUnit)") }
        guard options.rampEveryMeasures > 0 else { throw CLIError.invalidValue("--ramp-every", "\(options.rampEveryMeasures)") }
        if let polyrhythmBPM = options.polyrhythmBPM {
            guard polyrhythmBPM > 0 else { throw CLIError.invalidValue("--poly-bpm", "\(polyrhythmBPM)") }
        }
        guard options.polyrhythmBeats > 0 else { throw CLIError.invalidValue("--poly-beats", "\(options.polyrhythmBeats)") }
        if let polyrhythmOverBeats = options.polyrhythmOverBeats {
            guard polyrhythmOverBeats > 0 else { throw CLIError.invalidValue("--poly-over", "\(polyrhythmOverBeats)") }
        }
        guard (0...1).contains(options.accentGain) else { throw CLIError.invalidValue("--accent-gain", "\(options.accentGain)") }
        guard (0...1).contains(options.normalGain) else { throw CLIError.invalidValue("--normal-gain", "\(options.normalGain)") }
        guard (0...1).contains(options.subdivisionGain) else { throw CLIError.invalidValue("--subdivision-gain", "\(options.subdivisionGain)") }
        guard (0...1).contains(options.polyrhythmGain) else { throw CLIError.invalidValue("--poly-gain", "\(options.polyrhythmGain)") }
        if let grouping = options.grouping {
            options.beatsPerMeasure = grouping.reduce(0, +)
        }

        return options
    }

    private static func readString(_ arguments: [String], _ index: inout Int, option: String) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else { throw CLIError.missingValue(option) }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func readDouble(_ arguments: [String], _ index: inout Int, option: String) throws -> Double {
        let value = try readString(arguments, &index, option: option)
        guard let doubleValue = Double(value) else { throw CLIError.invalidValue(option, value) }
        return doubleValue
    }

    private static func readInt(_ arguments: [String], _ index: inout Int, option: String) throws -> Int {
        let value = try readString(arguments, &index, option: option)
        guard let intValue = Int(value) else { throw CLIError.invalidValue(option, value) }
        return intValue
    }

    private static func readFloat(_ arguments: [String], _ index: inout Int, option: String) throws -> Float {
        let value = try readString(arguments, &index, option: option)
        guard let floatValue = Float(value) else { throw CLIError.invalidValue(option, value) }
        return floatValue
    }

    private static func parseSubdivision(_ value: String, option: String) throws -> Subdivision {
        switch value {
        case "none", "1":
            .none
        case "eighths", "2":
            .eighths
        case "triplets", "3":
            .triplets
        case "sixteenths", "4":
            .sixteenths
        default:
            throw CLIError.invalidValue(option, value)
        }
    }

    private static func parseGrouping(_ value: String, option: String) throws -> [Int] {
        do {
            return try Pattern.parseGrouping(value)
        } catch {
            throw CLIError.invalidValue(option, value)
        }
    }

    private static func parsePreset(_ value: String, option: String) throws -> MetronomePreset {
        guard let preset = MetronomePreset(rawValue: value.lowercased()) else {
            throw CLIError.invalidValue(option, value)
        }
        return preset
    }

    private static func makePattern(options: CLIOptions) throws -> Pattern {
        if let preset = options.preset {
            return try preset.pattern
        }
        if let patternText = options.patternText {
            return try Pattern.parseBeatGrid(patternText)
        }
        if let grouping = options.grouping {
            return try Pattern.grouped(grouping)
        }
        return Pattern.regular(beatsPerMeasure: options.beatsPerMeasure)
    }

    private static func makeState(options: CLIOptions) throws -> MetronomeState {
        if let configPath = options.configPath {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            return try MetronomeSession.decode(from: data).state
        }

        let pattern = try makePattern(options: options)
        let beatUnit = options.preset?.beatUnit ?? options.beatUnit
        return MetronomeState(
            bpm: options.bpm,
            timeSignature: TimeSignature(beatsPerMeasure: pattern.beats.count, beatUnit: beatUnit),
            pattern: pattern,
            subdivision: options.subdivision,
            muteTrainer: options.muteEveryOtherMeasure ? .everyOtherMeasure : nil,
            tempoRamp: options.rampStep.map {
                TempoRamp(bpmStep: $0, everyMeasures: options.rampEveryMeasures, maximumBPM: options.rampMaximumBPM)
            },
            polyrhythm: makePolyrhythm(options: options),
            layerGains: LayerGains(
                accent: options.accentGain,
                normal: options.normalGain,
                subdivision: options.subdivisionGain,
                polyrhythm: options.polyrhythmGain
            ),
            isPlaying: true
        )
    }

    private static func saveSession(state: MetronomeState, path: String) throws {
        let session = MetronomeSession(state: state)
        try session.jsonData().write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private static func makePolyrhythm(options: CLIOptions) -> PolyrhythmSettings? {
        if let polyrhythmOverBeats = options.polyrhythmOverBeats {
            return .overPrimaryMeasure(beats: polyrhythmOverBeats)
        }
        return options.polyrhythmBPM.map {
            PolyrhythmSettings.regular(bpm: $0, beats: options.polyrhythmBeats)
        }
    }

    private static func helpText() -> String {
        """
        Usage:
          swift run r-metronome [options]

        Options:
          --bpm <number>              Tempo. Default: 120
          --duration <seconds>        Playback duration. Default: 10
          --beats <count>             Beats per measure. Default: 4
          --beat-unit <unit>          Beat unit. Default: 4
          --preset <name>             4/4|6/8|3+2+2|clave
          --grouping <pattern>        Accent grouping, for example 3+2+2
          --pattern <grid>            Beat grid, for example "A n n x"
          --mute-every-other          Mute every second measure while transport continues
          --ramp-step <bpm>           Change BPM by this amount at ramp boundaries
          --ramp-every <measures>     Measures per ramp step. Default: 4
          --ramp-max <bpm>            Optional maximum BPM for upward ramps
          --poly-bpm <number>         Enable a synchronized secondary rhythm
          --poly-beats <count>        Secondary pattern length. Default: 3
          --poly-over <count>         True polyrhythm: N beats over one primary measure
          --accent-gain <0...1>       Accent volume. Default: 1.0
          --normal-gain <0...1>       Normal volume. Default: 0.8
          --subdivision-gain <0...1>  Subdivision volume. Default: 0.6
          --poly-gain <0...1>         Polyrhythm volume. Default: 0.7
          --subdivision <value>       none|eighths|triplets|sixteenths or 1|2|3|4
          --sample-rate <hz>          Internal click buffer sample rate. Default: 48000
          --list-devices              Print CoreAudio output devices
          --list-presets              Print built-in presets
          --dry-run                   Print scheduled events without starting audio
          --config <path>             Load session JSON
          --save-config <path>        Save session JSON before running
          --help                      Show this help
        """
    }
}
