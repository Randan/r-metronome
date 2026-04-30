import Foundation

public enum MetronomePreset: String, CaseIterable, Equatable, Sendable {
    case fourFour = "4/4"
    case sixEight = "6/8"
    case sevenEight = "3+2+2"
    case clave = "clave"

    public var title: String {
        switch self {
        case .fourFour:
            "4/4"
        case .sixEight:
            "6/8"
        case .sevenEight:
            "3+2+2"
        case .clave:
            "Clave"
        }
    }

    public var beatUnit: Int {
        switch self {
        case .fourFour:
            4
        case .sixEight, .sevenEight, .clave:
            8
        }
    }

    public var pattern: Pattern {
        get throws {
            switch self {
            case .fourFour:
                Pattern.regular(beatsPerMeasure: 4)
            case .sixEight:
                try Pattern.grouped([3, 3])
            case .sevenEight:
                try Pattern.grouped([3, 2, 2])
            case .clave:
                try Pattern.parseBeatGrid("A x n x n x A x")
            }
        }
    }
}
