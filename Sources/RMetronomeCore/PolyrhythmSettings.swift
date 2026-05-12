import Foundation

public struct PolyrhythmSettings: Codable, Equatable, Sendable {
    public var bpm: Double
    public var pattern: Pattern
    public var locksToPrimaryMeasure: Bool

    public init(bpm: Double, pattern: Pattern, locksToPrimaryMeasure: Bool = false) {
        precondition(bpm > 0, "Polyrhythm BPM must be greater than zero")
        self.bpm = bpm
        self.pattern = pattern
        self.locksToPrimaryMeasure = locksToPrimaryMeasure
    }

    public static func regular(bpm: Double, beats: Int) -> PolyrhythmSettings {
        PolyrhythmSettings(bpm: bpm, pattern: .regular(beatsPerMeasure: beats))
    }

    public static func overPrimaryMeasure(beats: Int) -> PolyrhythmSettings {
        precondition(beats > 0, "Polyrhythm beats must be greater than zero")
        return PolyrhythmSettings(
            bpm: 1,
            pattern: .regular(beatsPerMeasure: beats),
            locksToPrimaryMeasure: true
        )
    }
}
