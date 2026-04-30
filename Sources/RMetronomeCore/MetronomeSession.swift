import Foundation

public struct MetronomeSession: Codable, Equatable, Sendable {
    public var version: Int
    public var state: MetronomeState

    public init(version: Int = 1, state: MetronomeState) {
        self.version = version
        self.state = state
    }

    public func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> MetronomeSession {
        try JSONDecoder().decode(MetronomeSession.self, from: data)
    }
}
