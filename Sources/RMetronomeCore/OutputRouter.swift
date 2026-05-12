import Foundation

public struct ChannelPair: Codable, Equatable, Hashable, Sendable {
    public var left: Int
    public var right: Int

    public init(left: Int, right: Int) {
        precondition(left >= 0, "left channel must be zero-based")
        precondition(right >= 0, "right channel must be zero-based")
        self.left = left
        self.right = right
    }

    public static let stereoMain = ChannelPair(left: 0, right: 1)

    public var displayName: String {
        "\(left + 1)-\(right + 1)"
    }
}

public struct OutputRouting: Equatable, Sendable {
    public var accent: ChannelPair
    public var normal: ChannelPair
    public var subdivision: ChannelPair
    public var polyrhythm: ChannelPair?

    public init(
        accent: ChannelPair = .stereoMain,
        normal: ChannelPair = .stereoMain,
        subdivision: ChannelPair = .stereoMain,
        polyrhythm: ChannelPair? = nil
    ) {
        self.accent = accent
        self.normal = normal
        self.subdivision = subdivision
        self.polyrhythm = polyrhythm
    }

    public func channelPair(for layer: ClickEvent.Layer) -> ChannelPair {
        switch layer {
        case .accent:
            accent
        case .normal:
            normal
        case .subdivision:
            subdivision
        case .polyrhythm:
            polyrhythm ?? .stereoMain
        }
    }
}
