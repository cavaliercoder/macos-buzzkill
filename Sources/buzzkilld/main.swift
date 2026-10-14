// buzzkilld — holds the default audio output stream open by rendering
// silence continuously. Works around the macOS Tahoe (26.x) bug where
// class-compliant USB interfaces (e.g. Allen & Heath CQ-18T) loop the last
// buffer and buzz when a client app stops/tears down playback.
import AudioToolbox
import BuzzkillCore

// Redirected stdout (launchd logs, the smoke test) is block-buffered, and
// SIGTERM never flushes it.
setvbuf(stdout, nil, _IOLBF, 0)

do {
    let unit = try makeSilenceUnit()
    let status = AudioOutputUnitStart(unit)
    guard status == noErr else {
        print("buzzkilld: AudioOutputUnitStart failed: \(status)")
        exit(1)
    }
} catch {
    print("buzzkilld: \(error)")
    exit(1)
}

print("buzzkilld: playing silence on default output unit")
RunLoop.main.run()
