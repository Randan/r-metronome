import XCTest
@testable import RMetronomeCore

final class MetronomeSchedulerTests: XCTestCase {
    func testBeatEventsUseSampleClock() {
        let state = MetronomeState(
            bpm: 60,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: .regular(beatsPerMeasure: 4),
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 44_100, startSampleTime: 0, state: state)

        let events = scheduler.events(from: 0, through: 132_300)

        XCTAssertEqual(events.map(\.sampleTime), [0, 44_100, 88_200, 132_300])
        XCTAssertEqual(events.map(\.layer), [.accent, .normal, .normal, .normal])
    }

    func testFractionalSamplesDoNotAccumulateRoundedIntervalDrift() {
        let state = MetronomeState(
            bpm: 123,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: .regular(beatsPerMeasure: 4),
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 44_100, startSampleTime: 10_000, state: state)

        let beat100 = scheduler.sampleTime(forBeat: 100)
        let expected = 10_000 + Int64(((44_100.0 * 60.0 / 123.0) * 100.0).rounded())

        XCTAssertEqual(beat100, expected)
    }

    func testMutedBeatsDoNotStopTransport() {
        let pattern = Pattern(beats: [
            Beat(kind: .accent),
            Beat(kind: .mute),
            Beat(kind: .normal),
            Beat(kind: .mute)
        ])
        let state = MetronomeState(
            bpm: 120,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: pattern,
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 48_000, startSampleTime: 0, state: state)

        let events = scheduler.events(from: 0, through: 96_000)

        XCTAssertEqual(events.map(\.sampleTime), [0, 48_000, 96_000])
        XCTAssertEqual(events.map(\.beatIndex), [0, 2, 4])
    }

    func testSubdivisionEventsAreScheduledBetweenBeats() {
        let state = MetronomeState(
            bpm: 60,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: .regular(beatsPerMeasure: 4),
            subdivision: .eighths,
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 48_000, startSampleTime: 0, state: state)

        let events = scheduler.events(from: 0, through: 72_000)

        XCTAssertEqual(events.map(\.sampleTime), [0, 24_000, 48_000, 72_000])
        XCTAssertEqual(events.map(\.layer), [.accent, .subdivision, .normal, .subdivision])
    }

    func testGroupedPatternAccentsEachGroupStart() throws {
        let pattern = try Pattern.grouped([3, 2, 2])
        let state = MetronomeState(
            bpm: 60,
            timeSignature: TimeSignature(beatsPerMeasure: 7, beatUnit: 8),
            pattern: pattern,
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 1_000, startSampleTime: 0, state: state)

        let events = scheduler.events(from: 0, through: 6_000)

        XCTAssertEqual(events.map(\.sampleTime), [0, 1_000, 2_000, 3_000, 4_000, 5_000, 6_000])
        XCTAssertEqual(events.map(\.layer), [.accent, .normal, .normal, .accent, .normal, .accent, .normal])
    }

    func testParseGrouping() throws {
        XCTAssertEqual(try Pattern.parseGrouping("3+2+2"), [3, 2, 2])
        XCTAssertEqual(try Pattern.parseGrouping(" 5 + 4 "), [5, 4])
        XCTAssertThrowsError(try Pattern.parseGrouping("3++2"))
        XCTAssertThrowsError(try Pattern.parseGrouping("3+0+2"))
    }

    func testParseBeatGridPattern() throws {
        let pattern = try Pattern.parseBeatGrid("A n x normal mute")

        XCTAssertEqual(pattern.beats.map(\.kind), [.accent, .normal, .mute, .normal, .mute])
        XCTAssertEqual(pattern.beatGridString, "A n x n x")
        XCTAssertThrowsError(try Pattern.parseBeatGrid("A nope n"))
    }

    func testLayerGainsClampToUnitRange() {
        let gains = LayerGains(accent: 1.5, normal: -1, subdivision: 0.25)

        XCTAssertEqual(gains.accent, 1)
        XCTAssertEqual(gains.normal, 0)
        XCTAssertEqual(gains.subdivision, 0.25)
    }

    func testMetronomePresetsProduceExpectedPatterns() throws {
        let sixEight = try MetronomePreset.sixEight.pattern
        let sevenEight = try MetronomePreset.sevenEight.pattern
        let clave = try MetronomePreset.clave.pattern

        XCTAssertEqual(MetronomePreset.sixEight.beatUnit, 8)
        XCTAssertEqual(sixEight.beatGridString, "A n n A n n")
        XCTAssertEqual(sevenEight.beatGridString, "A n n A n A n")
        XCTAssertEqual(clave.beatGridString, "A x n x n x A x")
    }

    func testStateSummaryIncludesPracticeOptions() {
        let state = MetronomeState(
            bpm: 100,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: .regular(beatsPerMeasure: 4),
            subdivision: .eighths,
            muteTrainer: .everyOtherMeasure,
            tempoRamp: TempoRamp(bpmStep: 5, everyMeasures: 2, maximumBPM: 140),
            isPlaying: true
        )

        XCTAssertEqual(
            state.summary,
            "100 BPM, 4/4, A n n n, subdivision eighths, mute trainer, ramp +5 BPM every 2 measures, max 140"
        )
    }

    func testMuteTrainerSkipsEventsWithoutStoppingTransport() {
        let state = MetronomeState(
            bpm: 60,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: .regular(beatsPerMeasure: 4),
            subdivision: .eighths,
            muteTrainer: .everyOtherMeasure,
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 1_000, startSampleTime: 0, state: state)

        let events = scheduler.events(from: 0, through: 8_500)

        XCTAssertEqual(events.map(\.sampleTime), [0, 500, 1_000, 1_500, 2_000, 2_500, 3_000, 3_500, 8_000, 8_500])
        XCTAssertEqual(events.map(\.beatIndex), [0, 0, 1, 1, 2, 2, 3, 3, 8, 8])
    }

    func testTempoRampChangesBPMAtMeasureBoundary() {
        let state = MetronomeState(
            bpm: 60,
            timeSignature: TimeSignature(beatsPerMeasure: 4, beatUnit: 4),
            pattern: .regular(beatsPerMeasure: 4),
            tempoRamp: TempoRamp(bpmStep: 60, everyMeasures: 1),
            isPlaying: true
        )
        let scheduler = MetronomeScheduler(sampleRate: 1_000, startSampleTime: 0, state: state)

        let events = scheduler.events(from: 0, through: 5_500)

        XCTAssertEqual(events.map(\.sampleTime), [0, 1_000, 2_000, 3_000, 4_000, 4_500, 5_000, 5_500])
        XCTAssertEqual(events.map(\.beatIndex), [0, 1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(scheduler.bpm(forMeasure: 0), 60)
        XCTAssertEqual(scheduler.bpm(forMeasure: 1), 120)
    }

    func testTempoRampMaximumBPMCapsUpwardRamp() {
        let ramp = TempoRamp(bpmStep: 20, everyMeasures: 1, maximumBPM: 90)

        XCTAssertEqual(ramp.bpm(baseBPM: 70, measureIndex: 0), 70)
        XCTAssertEqual(ramp.bpm(baseBPM: 70, measureIndex: 1), 90)
        XCTAssertEqual(ramp.bpm(baseBPM: 70, measureIndex: 2), 90)
    }
}
