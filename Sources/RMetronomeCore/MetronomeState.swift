import Foundation

public struct MetronomeState: Equatable, Sendable {
    public var bpm: Double
    public var timeSignature: TimeSignature
    public var pattern: Pattern
    public var subdivision: Subdivision
    public var muteTrainer: MuteTrainer?
    public var tempoRamp: TempoRamp?
    public var polyrhythm: PolyrhythmSettings?
    public var layerGains: LayerGains
    public var isPlaying: Bool

    public init(
        bpm: Double,
        timeSignature: TimeSignature,
        pattern: Pattern,
        subdivision: Subdivision = .none,
        muteTrainer: MuteTrainer? = nil,
        tempoRamp: TempoRamp? = nil,
        polyrhythm: PolyrhythmSettings? = nil,
        layerGains: LayerGains = .default,
        isPlaying: Bool = false
    ) {
        precondition(bpm > 0, "BPM must be greater than zero")
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.pattern = pattern
        self.subdivision = subdivision
        self.muteTrainer = muteTrainer
        self.tempoRamp = tempoRamp
        self.polyrhythm = polyrhythm
        self.layerGains = layerGains
        self.isPlaying = isPlaying
    }
}

public struct LayerGains: Equatable, Sendable {
    public var accent: Float
    public var normal: Float
    public var subdivision: Float
    public var polyrhythm: Float

    public init(accent: Float = 1.0, normal: Float = 0.8, subdivision: Float = 0.6, polyrhythm: Float = 0.7) {
        self.accent = Self.clamp(accent)
        self.normal = Self.clamp(normal)
        self.subdivision = Self.clamp(subdivision)
        self.polyrhythm = Self.clamp(polyrhythm)
    }

    public static let `default` = LayerGains()

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct TimeSignature: Equatable, Sendable {
    public var beatsPerMeasure: Int
    public var beatUnit: Int

    public init(beatsPerMeasure: Int, beatUnit: Int) {
        precondition(beatsPerMeasure > 0, "beatsPerMeasure must be greater than zero")
        precondition(beatUnit > 0, "beatUnit must be greater than zero")
        self.beatsPerMeasure = beatsPerMeasure
        self.beatUnit = beatUnit
    }
}

public extension MetronomeState {
    var summary: String {
        var parts = [
            "\(Int(bpm.rounded())) BPM",
            "\(timeSignature.beatsPerMeasure)/\(timeSignature.beatUnit)",
            pattern.beatGridString
        ]

        if subdivision != .none {
            parts.append("subdivision \(subdivision.title)")
        }
        if muteTrainer != nil {
            parts.append("mute trainer")
        }
        if let tempoRamp {
            parts.append("ramp \(tempoRamp.summary)")
        }
        if let polyrhythm {
            parts.append("poly \(Int(polyrhythm.bpm.rounded())) BPM")
        }

        return parts.joined(separator: ", ")
    }
}

public enum Subdivision: Int, Equatable, Sendable {
    case none = 1
    case eighths = 2
    case triplets = 3
    case sixteenths = 4

    public var title: String {
        switch self {
        case .none:
            "none"
        case .eighths:
            "eighths"
        case .triplets:
            "triplets"
        case .sixteenths:
            "sixteenths"
        }
    }
}
