import Foundation

public struct Beat: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case accent
        case normal
        case mute
    }

    public var kind: Kind
    public var weight: Int

    public init(kind: Kind, weight: Int = 1) {
        precondition(weight > 0, "weight must be greater than zero")
        self.kind = kind
        self.weight = weight
    }
}

public struct Pattern: Equatable, Sendable {
    public var beats: [Beat]
    public var grouping: [Int]

    public init(beats: [Beat], grouping: [Int] = []) {
        precondition(!beats.isEmpty, "Pattern must contain at least one beat")
        precondition(grouping.allSatisfy { $0 > 0 }, "Grouping values must be greater than zero")
        self.beats = beats
        self.grouping = grouping
    }

    public static func regular(beatsPerMeasure: Int) -> Pattern {
        precondition(beatsPerMeasure > 0, "beatsPerMeasure must be greater than zero")
        let beats = (0..<beatsPerMeasure).map { index in
            Beat(kind: index == 0 ? .accent : .normal)
        }
        return Pattern(beats: beats)
    }

    public static func grouped(_ grouping: [Int]) throws -> Pattern {
        guard !grouping.isEmpty else { throw PatternError.emptyGrouping }
        guard grouping.allSatisfy({ $0 > 0 }) else { throw PatternError.invalidGrouping }

        var beats: [Beat] = []
        for groupSize in grouping {
            for index in 0..<groupSize {
                beats.append(Beat(kind: index == 0 ? .accent : .normal))
            }
        }

        return Pattern(beats: beats, grouping: grouping)
    }

    public static func parseGrouping(_ text: String) throws -> [Int] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PatternError.emptyGrouping }

        let parts = trimmed.split(separator: "+", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { throw PatternError.emptyGrouping }

        var grouping: [Int] = []
        for part in parts {
            let valueText = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Int(valueText), value > 0 else {
                throw PatternError.invalidGrouping
            }
            grouping.append(value)
        }
        return grouping
    }

    public static func parseBeatGrid(_ text: String) throws -> Pattern {
        let tokens = text
            .split { character in
                character == " " || character == "," || character == "|" || character == "-"
            }
            .map(String.init)

        guard !tokens.isEmpty else { throw PatternError.emptyPattern }

        var beats: [Beat] = []
        for token in tokens {
            switch token.lowercased() {
            case "a", "accent", "1":
                beats.append(Beat(kind: .accent))
            case "n", "normal", ".":
                beats.append(Beat(kind: .normal))
            case "m", "mute", "x", "0":
                beats.append(Beat(kind: .mute))
            default:
                throw PatternError.invalidPatternToken(token)
            }
        }

        return Pattern(beats: beats)
    }

    public var beatGridString: String {
        beats.map { beat in
            switch beat.kind {
            case .accent:
                "A"
            case .normal:
                "n"
            case .mute:
                "x"
            }
        }
        .joined(separator: " ")
    }
}

public enum PatternError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyGrouping
    case invalidGrouping
    case emptyPattern
    case invalidPatternToken(String)

    public var description: String {
        switch self {
        case .emptyGrouping:
            "Grouping must not be empty"
        case .invalidGrouping:
            "Grouping must contain positive integers separated by +"
        case .emptyPattern:
            "Pattern must not be empty"
        case let .invalidPatternToken(token):
            "Invalid pattern token: \(token)"
        }
    }
}
