import AudioToolbox

/// Zeroes every buffer in the list. This is the entire render path of
/// buzzkilld: the output stream stays open, but only silence is written.
public func zeroBuffers(_ ioData: UnsafeMutablePointer<AudioBufferList>?) {
    guard let ioData = ioData else { return }
    for buffer in UnsafeMutableAudioBufferListPointer(ioData) {
        if let data = buffer.mData {
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
}

/// The AURenderCallback installed on the output unit.
public let renderSilence: AURenderCallback = { _, _, _, _, _, ioData in
    zeroBuffers(ioData)
    return noErr
}

public enum SilenceUnitError: Error, CustomStringConvertible {
    case componentNotFound
    case osStatus(String, OSStatus)

    public var description: String {
        switch self {
        case .componentNotFound:
            return "default output audio unit not found"
        case .osStatus(let stage, let status):
            return "\(stage) failed: \(status)"
        }
    }
}

/// Creates and initializes (but does not start) a DefaultOutput audio unit
/// with the silence render callback installed. Output-only: never touches
/// input/microphone, so no TCC prompt. The DefaultOutput unit follows the
/// system default output device automatically.
public func makeSilenceUnit() throws -> AudioUnit {
    var desc = AudioComponentDescription(
        componentType: kAudioUnitType_Output,
        componentSubType: kAudioUnitSubType_DefaultOutput,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )
    guard let component = AudioComponentFindNext(nil, &desc) else {
        throw SilenceUnitError.componentNotFound
    }

    var maybeUnit: AudioUnit?
    var status = AudioComponentInstanceNew(component, &maybeUnit)
    guard status == noErr, let unit = maybeUnit else {
        throw SilenceUnitError.osStatus("AudioComponentInstanceNew", status)
    }

    var callback = AURenderCallbackStruct(inputProc: renderSilence, inputProcRefCon: nil)
    status = AudioUnitSetProperty(
        unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
        &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size)
    )
    guard status == noErr else {
        AudioComponentInstanceDispose(unit)
        throw SilenceUnitError.osStatus("SetRenderCallback", status)
    }

    status = AudioUnitInitialize(unit)
    guard status == noErr else {
        AudioComponentInstanceDispose(unit)
        throw SilenceUnitError.osStatus("AudioUnitInitialize", status)
    }

    return unit
}
