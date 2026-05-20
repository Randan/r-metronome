import Foundation

public struct ClickEvent: Equatable, Sendable {
    public enum Layer: CaseIterable, Equatable, Sendable {
        case accent
        case normal
        case subdivision
        case polyrhythm
    }

    public var sampleTime: Int64
    public var beatIndex: Int64
    public var subdivisionIndex: Int
    public var layer: Layer

    public init(sampleTime: Int64, beatIndex: Int64, subdivisionIndex: Int, layer: Layer) {
        self.sampleTime = sampleTime
        self.beatIndex = beatIndex
        self.subdivisionIndex = subdivisionIndex
        self.layer = layer
    }
}

public struct MetronomeScheduler: Sendable {
    public var sampleRate: Double
    public var startSampleTime: Int64
    public var state: MetronomeState

    public init(sampleRate: Double, startSampleTime: Int64, state: MetronomeState) {
        precondition(sampleRate > 0, "sampleRate must be greater than zero")
        self.sampleRate = sampleRate
        self.startSampleTime = startSampleTime
        self.state = state
    }

    public var samplesPerBeat: Double {
        sampleRate * 60.0 / state.bpm
    }

    public func events(from lowerBound: Int64, through upperBound: Int64) -> [ClickEvent] {
        guard state.isPlaying, upperBound >= lowerBound else { return [] }
        let primaryEvents = scheduledEvents(
            from: lowerBound,
            through: upperBound,
            pattern: state.pattern,
            subdivision: state.subdivision,
            outputLayerOverride: nil,
            isMuted: isMuted(beatIndex:)
        )

        guard let polyrhythm = state.polyrhythm else { return primaryEvents }

        if polyrhythm.locksToPrimaryMeasure {
            return (primaryEvents + lockedPolyrhythmEvents(from: lowerBound, through: upperBound, settings: polyrhythm))
                .sorted(by: eventSort)
        }

        let secondaryState = MetronomeState(
            bpm: polyrhythm.bpm,
            timeSignature: TimeSignature(beatsPerMeasure: polyrhythm.pattern.beats.count, beatUnit: state.timeSignature.beatUnit),
            pattern: polyrhythm.pattern,
            isPlaying: true
        )
        let secondaryScheduler = MetronomeScheduler(sampleRate: sampleRate, startSampleTime: startSampleTime, state: secondaryState)
        let secondaryEvents = secondaryScheduler.scheduledEvents(
            from: lowerBound,
            through: upperBound,
            pattern: polyrhythm.pattern,
            subdivision: .none,
            outputLayerOverride: .polyrhythm,
            isMuted: { _ in false }
        )

        return (primaryEvents + secondaryEvents).sorted(by: eventSort)
    }

    private func lockedPolyrhythmEvents(
        from lowerBound: Int64,
        through upperBound: Int64,
        settings: PolyrhythmSettings
    ) -> [ClickEvent] {
        let primaryBeatsPerMeasure = Int64(state.pattern.beats.count)
        let polyrhythmBeats = settings.pattern.beats.count
        let firstMeasure = max(0, Int(beatIndex(atOrBefore: lowerBound) / primaryBeatsPerMeasure) - 1)
        let lastMeasure = max(0, Int(beatIndex(atOrBefore: upperBound) / primaryBeatsPerMeasure) + 2)

        var result: [ClickEvent] = []
        for measureIndex in firstMeasure...lastMeasure {
            let measureStart = sampleTime(forBeat: Int64(measureIndex) * primaryBeatsPerMeasure)
            let measureEnd = sampleTime(forBeat: Int64(measureIndex + 1) * primaryBeatsPerMeasure)
            let measureDuration = measureEnd - measureStart

            for polyrhythmIndex in 0..<polyrhythmBeats {
                let offset = Double(measureDuration) * Double(polyrhythmIndex) / Double(polyrhythmBeats)
                let sampleTime = measureStart + Int64(offset.rounded())
                if sampleTime >= lowerBound, sampleTime <= upperBound {
                    result.append(
                        ClickEvent(
                            sampleTime: sampleTime,
                            beatIndex: Int64(measureIndex * polyrhythmBeats + polyrhythmIndex),
                            subdivisionIndex: polyrhythmIndex,
                            layer: .polyrhythm
                        )
                    )
                }
            }
        }

        return result
    }

    private func scheduledEvents(
        from lowerBound: Int64,
        through upperBound: Int64,
        pattern: Pattern,
        subdivision: Subdivision,
        outputLayerOverride: ClickEvent.Layer?,
        isMuted: (Int64) -> Bool
    ) -> [ClickEvent] {

        let firstBeat = max(0, beatIndex(atOrBefore: lowerBound) - 1)
        let lastBeat = max(0, beatIndex(atOrBefore: upperBound) + 2)

        var result: [ClickEvent] = []
        for beatIndex in firstBeat...lastBeat {
            guard !isMuted(beatIndex) else { continue }

            let beatSample = sampleTime(forBeat: beatIndex)
            if beatSample >= lowerBound, beatSample <= upperBound {
                if var event = beatEvent(beatIndex: beatIndex, sampleTime: beatSample, pattern: pattern) {
                    if let outputLayerOverride {
                        event.layer = outputLayerOverride
                    }
                    result.append(event)
                }
            }

            guard subdivision != .none else { continue }
            let subdivisionCount = subdivision.rawValue
            for subdivisionIndex in 1..<subdivisionCount {
                let offset = samplesPerBeat(forBeat: beatIndex) * Double(subdivisionIndex) / Double(subdivisionCount)
                let subdivisionSample = beatSample + Int64(offset.rounded())
                if subdivisionSample >= lowerBound, subdivisionSample <= upperBound {
                    result.append(
                        ClickEvent(
                            sampleTime: subdivisionSample,
                            beatIndex: beatIndex,
                            subdivisionIndex: subdivisionIndex,
                            layer: .subdivision
                        )
                    )
                }
            }
        }

        return result.sorted(by: eventSort)
    }

    public func sampleTime(forBeat beatIndex: Int64) -> Int64 {
        guard state.tempoRamp != nil else {
            return startSampleTime + Int64((Double(beatIndex) * samplesPerBeat).rounded())
        }

        let beatsPerMeasure = Int64(state.pattern.beats.count)
        let measureIndex = Int(beatIndex / beatsPerMeasure)
        let beatInMeasure = Int(beatIndex % beatsPerMeasure)

        var sampleOffset = 0.0
        if measureIndex > 0 {
            for index in 0..<measureIndex {
                sampleOffset += samplesPerBeat(forMeasure: index) * Double(beatsPerMeasure)
            }
        }
        sampleOffset += samplesPerBeat(forMeasure: measureIndex) * Double(beatInMeasure)

        return startSampleTime + Int64(sampleOffset.rounded())
    }

    public func bpm(forMeasure measureIndex: Int) -> Double {
        state.tempoRamp?.bpm(baseBPM: state.bpm, measureIndex: measureIndex) ?? state.bpm
    }

    private func beatEvent(beatIndex: Int64, sampleTime: Int64, pattern: Pattern) -> ClickEvent? {
        let patternIndex = Int(beatIndex % Int64(pattern.beats.count))
        switch pattern.beats[patternIndex].kind {
        case .accent:
            return ClickEvent(sampleTime: sampleTime, beatIndex: beatIndex, subdivisionIndex: 0, layer: .accent)
        case .normal:
            return ClickEvent(sampleTime: sampleTime, beatIndex: beatIndex, subdivisionIndex: 0, layer: .normal)
        case .mute:
            return nil
        }
    }

    private func isMuted(beatIndex: Int64) -> Bool {
        guard let muteTrainer = state.muteTrainer else { return false }
        let measureIndex = Int(beatIndex / Int64(state.pattern.beats.count))
        return muteTrainer.isMuted(measureIndex: measureIndex)
    }

    private func samplesPerBeat(forBeat beatIndex: Int64) -> Double {
        let measureIndex = Int(beatIndex / Int64(state.pattern.beats.count))
        return samplesPerBeat(forMeasure: measureIndex)
    }

    private func samplesPerBeat(forMeasure measureIndex: Int) -> Double {
        sampleRate * 60.0 / bpm(forMeasure: measureIndex)
    }

    private func beatIndex(atOrBefore sampleTime: Int64) -> Int64 {
        guard sampleTime > startSampleTime else { return 0 }

        var upper: Int64 = 1
        while self.sampleTime(forBeat: upper) <= sampleTime {
            upper *= 2
        }

        var lower: Int64 = 0
        while lower + 1 < upper {
            let midpoint = (lower + upper) / 2
            if self.sampleTime(forBeat: midpoint) <= sampleTime {
                lower = midpoint
            } else {
                upper = midpoint
            }
        }

        return lower
    }

    private func eventSort(_ lhs: ClickEvent, _ rhs: ClickEvent) -> Bool {
        if lhs.sampleTime == rhs.sampleTime {
            if lhs.subdivisionIndex == rhs.subdivisionIndex {
                return layerSortIndex(lhs.layer) < layerSortIndex(rhs.layer)
            }
            return lhs.subdivisionIndex < rhs.subdivisionIndex
        }
        return lhs.sampleTime < rhs.sampleTime
    }

    private func layerSortIndex(_ layer: ClickEvent.Layer) -> Int {
        switch layer {
        case .accent:
            0
        case .normal:
            1
        case .subdivision:
            2
        case .polyrhythm:
            3
        }
    }
}
