// buzzkilld — holds the default audio output stream open by rendering
// silence continuously. Works around the macOS Tahoe (26.x) bug where
// class-compliant USB interfaces (e.g. Allen & Heath CQ-18T) loop the last
// buffer and buzz when a client app stops/tears down playback.
//
// Uses a raw CoreAudio DefaultOutput unit (output-only): no microphone/input
// access, so no TCC permission prompt. The DefaultOutput unit automatically
// follows the system default output device.
// Build: make (or: swiftc -O buzzkilld.swift -o buzzkilld)
import AudioToolbox

let renderSilence: AURenderCallback = { _, _, _, _, _, ioData -> OSStatus in
    if let ioData = ioData {
        for buffer in UnsafeMutableAudioBufferListPointer(ioData) {
            if let data = buffer.mData {
                memset(data, 0, Int(buffer.mDataByteSize))
            }
        }
    }
    return noErr
}

var desc = AudioComponentDescription(
    componentType: kAudioUnitType_Output,
    componentSubType: kAudioUnitSubType_DefaultOutput,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0,
    componentFlagsMask: 0
)

guard let component = AudioComponentFindNext(nil, &desc) else {
    print("buzzkilld: default output unit not found")
    exit(1)
}

var maybeUnit: AudioUnit?
var status = AudioComponentInstanceNew(component, &maybeUnit)
guard status == noErr, let unit = maybeUnit else {
    print("buzzkilld: AudioComponentInstanceNew failed: \(status)")
    exit(1)
}

var callback = AURenderCallbackStruct(inputProc: renderSilence, inputProcRefCon: nil)
status = AudioUnitSetProperty(
    unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
    &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size)
)
guard status == noErr else {
    print("buzzkilld: SetRenderCallback failed: \(status)")
    exit(1)
}

status = AudioUnitInitialize(unit)
guard status == noErr else {
    print("buzzkilld: AudioUnitInitialize failed: \(status)")
    exit(1)
}

status = AudioOutputUnitStart(unit)
guard status == noErr else {
    print("buzzkilld: AudioOutputUnitStart failed: \(status)")
    exit(1)
}

print("buzzkilld: playing silence on default output unit")
RunLoop.main.run()
