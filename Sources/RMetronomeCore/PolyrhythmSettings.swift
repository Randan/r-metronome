import Foundation

public struct PolyrhythmSettings: Codable, Equatable, Sendable {
    public var bpm: Double
    public var pattern: Pattern

    public init(bpm: Double, pattern: Pattern) {
        precondition(bpm > 0, "Polyrhythm BPM must be greater than zero")
        self.bpm = bpm
        self.pattern = pattern
    }

    public static func regular(bpm: Double, beats: Int) -> PolyrhythmSettings {
        PolyrhythmSettings(bpm: bpm, pattern: .regular(beatsPerMeasure: beats))
    }
}
