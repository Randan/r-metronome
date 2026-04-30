import Foundation

public struct TempoRamp: Equatable, Sendable {
    public var bpmStep: Double
    public var everyMeasures: Int
    public var maximumBPM: Double?

    public init(bpmStep: Double, everyMeasures: Int, maximumBPM: Double? = nil) {
        precondition(everyMeasures > 0, "everyMeasures must be greater than zero")
        self.bpmStep = bpmStep
        self.everyMeasures = everyMeasures
        self.maximumBPM = maximumBPM
    }

    public func bpm(baseBPM: Double, measureIndex: Int) -> Double {
        let steps = measureIndex / everyMeasures
        let ramped = baseBPM + Double(steps) * bpmStep
        let bounded: Double
        if let maximumBPM {
            bounded = min(ramped, maximumBPM)
        } else {
            bounded = ramped
        }
        return max(1.0, bounded)
    }

    public var summary: String {
        let sign = bpmStep >= 0 ? "+" : ""
        let cap = maximumBPM.map { ", max \(Int($0.rounded()))" } ?? ""
        return "\(sign)\(Int(bpmStep.rounded())) BPM every \(everyMeasures) measures\(cap)"
    }
}

public struct MuteTrainer: Equatable, Sendable {
    public var mutedMeasures: Set<Int>
    public var cycleLengthMeasures: Int?

    public init(mutedMeasures: Set<Int>, cycleLengthMeasures: Int? = nil) {
        precondition(mutedMeasures.allSatisfy { $0 >= 0 }, "Muted measure indexes must be zero-based")
        if let cycleLengthMeasures {
            precondition(cycleLengthMeasures > 0, "cycleLengthMeasures must be greater than zero")
            precondition(mutedMeasures.allSatisfy { $0 < cycleLengthMeasures }, "Muted measure indexes must fit inside cycleLengthMeasures")
        }
        self.mutedMeasures = mutedMeasures
        self.cycleLengthMeasures = cycleLengthMeasures
    }

    public func isMuted(measureIndex: Int) -> Bool {
        guard let cycleLengthMeasures else {
            return mutedMeasures.contains(measureIndex)
        }
        return mutedMeasures.contains(measureIndex % cycleLengthMeasures)
    }

    public static let everyOtherMeasure = MuteTrainer(mutedMeasures: [1], cycleLengthMeasures: 2)
}
