import CoreAudio
import Foundation

public struct AudioOutputDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: AudioObjectID
    public var name: String
    public var outputChannelCount: Int

    public init(id: AudioObjectID, name: String, outputChannelCount: Int) {
        self.id = id
        self.name = name
        self.outputChannelCount = outputChannelCount
    }

    public var channelPairs: [ChannelPair] {
        stride(from: 0, to: outputChannelCount, by: 2).compactMap { left in
            let right = left + 1
            guard right < outputChannelCount else { return nil }
            return ChannelPair(left: left, right: right)
        }
    }
}

public enum OutputDeviceManager {
    public static func outputDevices() throws -> [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        guard status == noErr else { throw CoreAudioError(status: status) }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids)
        guard status == noErr else { throw CoreAudioError(status: status) }

        return try ids.compactMap { id in
            let channels = try outputChannelCount(deviceID: id)
            guard channels > 0 else { return nil }
            return AudioOutputDevice(id: id, name: try deviceName(deviceID: id), outputChannelCount: channels)
        }
    }

    private static func deviceName(deviceID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
        guard status == noErr else { throw CoreAudioError(status: status) }
        return name as String
    }

    private static func outputChannelCount(deviceID: AudioObjectID) throws -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr else { throw CoreAudioError(status: status) }

        let bufferList = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferList.deallocate() }

        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList)
        guard status == noErr else { throw CoreAudioError(status: status) }

        let audioBufferList = bufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        let unsafeList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return unsafeList.reduce(0) { total, buffer in
            total + Int(buffer.mNumberChannels)
        }
    }
}

public struct CoreAudioError: Error, Equatable, Sendable {
    public var status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }
}
