import CoreAudio
import Foundation

public struct AudioOutputSelection: Codable, Equatable, Sendable {
    public var deviceID: AudioObjectID?
    public var channelPair: ChannelPair

    public init(deviceID: AudioObjectID? = nil, channelPair: ChannelPair = .stereoMain) {
        self.deviceID = deviceID
        self.channelPair = channelPair
    }

    public static let systemDefault = AudioOutputSelection()
}
