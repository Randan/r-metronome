import CoreAudio
import Foundation

public struct AudioOutputDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: AudioObjectID
    public var name: String
    public var outputChannelCount: Int
    public var transportType: UInt32?
    public var reportedLatencyMilliseconds: Double?

    public init(
        id: AudioObjectID,
        name: String,
        outputChannelCount: Int,
        transportType: UInt32? = nil,
        reportedLatencyMilliseconds: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.outputChannelCount = outputChannelCount
        self.transportType = transportType
        self.reportedLatencyMilliseconds = reportedLatencyMilliseconds
    }

    public var channelPairs: [ChannelPair] {
        stride(from: 0, to: outputChannelCount, by: 2).compactMap { left in
            let right = left + 1
            guard right < outputChannelCount else { return nil }
            return ChannelPair(left: left, right: right)
        }
    }

    public var isWireless: Bool {
        let lowercasedName = name.lowercased()
        return lowercasedName.contains("airpods")
            || lowercasedName.contains("bluetooth")
            || lowercasedName.contains("beats")
            || transportTypeName.lowercased().contains("blue")
            || transportTypeName.lowercased().contains("ble")
    }

    public var transportTypeName: String {
        guard let transportType else { return "Unknown" }
        return Self.fourCharacterCodeString(transportType)
    }

    private static func fourCharacterCodeString(_ value: UInt32) -> String {
        let scalars = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]

        let characters = scalars.map { byte in
            if byte >= 32 && byte <= 126 {
                return Character(UnicodeScalar(byte))
            }
            return "?"
        }
        return String(characters)
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
            return AudioOutputDevice(
                id: id,
                name: try deviceName(deviceID: id),
                outputChannelCount: channels,
                transportType: transportType(deviceID: id),
                reportedLatencyMilliseconds: reportedLatencyMilliseconds(deviceID: id)
            )
        }
    }

    private static func deviceName(deviceID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr else { throw CoreAudioError(status: status) }
        return name as String? ?? "Output \(deviceID)"
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

    private static func transportType(deviceID: AudioObjectID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &transportType)
        guard status == noErr else { return nil }
        return transportType
    }

    private static func reportedLatencyMilliseconds(deviceID: AudioObjectID) -> Double? {
        guard let sampleRate = nominalSampleRate(deviceID: deviceID), sampleRate > 0 else { return nil }

        let latencyFrames = outputUInt32Property(
            deviceID: deviceID,
            selector: kAudioDevicePropertyLatency,
            scope: kAudioDevicePropertyScopeOutput
        ) ?? 0
        let safetyOffsetFrames = outputUInt32Property(
            deviceID: deviceID,
            selector: kAudioDevicePropertySafetyOffset,
            scope: kAudioDevicePropertyScopeOutput
        ) ?? 0
        let bufferFrames = outputUInt32Property(
            deviceID: deviceID,
            selector: kAudioDevicePropertyBufferFrameSize,
            scope: kAudioObjectPropertyScopeGlobal
        ) ?? 0

        let totalFrames = Double(latencyFrames + safetyOffsetFrames + bufferFrames)
        guard totalFrames > 0 else { return nil }
        return totalFrames / sampleRate * 1_000.0
    }

    private static func outputUInt32Property(
        deviceID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
        guard status == noErr else { return nil }
        return value
    }

    private static func nominalSampleRate(deviceID: AudioObjectID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate = Float64(0)
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &sampleRate)
        guard status == noErr else { return nil }
        return sampleRate
    }
}

public struct CoreAudioError: Error, Equatable, Sendable {
    public var status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }
}
