import Foundation

public struct PolyrhythmScheduler: Sendable {
    public var primary: MetronomeScheduler
    public var secondary: MetronomeScheduler

    public init(primary: MetronomeScheduler, secondary: MetronomeScheduler) {
        precondition(primary.startSampleTime == secondary.startSampleTime, "Schedulers must share the same start sample time")
        self.primary = primary
        self.secondary = secondary
    }

    public func events(from lowerBound: Int64, through upperBound: Int64) -> [ClickEvent] {
        (primary.events(from: lowerBound, through: upperBound) + secondary.events(from: lowerBound, through: upperBound))
            .sorted { lhs, rhs in
                if lhs.sampleTime == rhs.sampleTime {
                    return lhs.beatIndex < rhs.beatIndex
                }
                return lhs.sampleTime < rhs.sampleTime
            }
    }
}
