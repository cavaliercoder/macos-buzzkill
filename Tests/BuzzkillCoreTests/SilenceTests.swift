import AudioToolbox
import Testing
@testable import BuzzkillCore

struct SilenceTests {
    private func makeDirtyBufferList(buffers: Int, bytesPerBuffer: Int)
        -> (UnsafeMutableAudioBufferListPointer, [UnsafeMutableRawPointer]) {
        let abl = AudioBufferList.allocate(maximumBuffers: buffers)
        var allocations: [UnsafeMutableRawPointer] = []
        for i in 0..<buffers {
            let data = UnsafeMutableRawPointer.allocate(byteCount: bytesPerBuffer, alignment: 16)
            memset(data, 0xAB, bytesPerBuffer)
            allocations.append(data)
            abl[i] = AudioBuffer(
                mNumberChannels: 2,
                mDataByteSize: UInt32(bytesPerBuffer),
                mData: data
            )
        }
        return (abl, allocations)
    }

    private func expectAllZero(_ data: UnsafeMutableRawPointer, _ count: Int,
                               sourceLocation: SourceLocation = #_sourceLocation) {
        let bytes = data.bindMemory(to: UInt8.self, capacity: count)
        for i in 0..<count {
            if bytes[i] != 0 {
                Issue.record("byte \(i) is \(bytes[i]), expected 0", sourceLocation: sourceLocation)
                return
            }
        }
    }

    @Test func zeroBuffersZeroesSingleBuffer() {
        let (abl, allocations) = makeDirtyBufferList(buffers: 1, bytesPerBuffer: 4096)
        defer { allocations.forEach { $0.deallocate() }; free(abl.unsafeMutablePointer) }

        zeroBuffers(abl.unsafeMutablePointer)
        expectAllZero(allocations[0], 4096)
    }

    @Test func zeroBuffersZeroesAllBuffersInList() {
        let (abl, allocations) = makeDirtyBufferList(buffers: 3, bytesPerBuffer: 512)
        defer { allocations.forEach { $0.deallocate() }; free(abl.unsafeMutablePointer) }

        zeroBuffers(abl.unsafeMutablePointer)
        for data in allocations {
            expectAllZero(data, 512)
        }
    }

    @Test func zeroBuffersHandlesNilListAndNilData() {
        zeroBuffers(nil) // must not crash

        let abl = AudioBufferList.allocate(maximumBuffers: 1)
        defer { free(abl.unsafeMutablePointer) }
        abl[0] = AudioBuffer(mNumberChannels: 2, mDataByteSize: 1024, mData: nil)
        zeroBuffers(abl.unsafeMutablePointer) // must not crash
    }

    @Test func renderCallbackReturnsNoErrAndZeroes() {
        let (abl, allocations) = makeDirtyBufferList(buffers: 1, bytesPerBuffer: 256)
        defer { allocations.forEach { $0.deallocate() }; free(abl.unsafeMutablePointer) }

        var flags = AudioUnitRenderActionFlags()
        var timestamp = AudioTimeStamp()
        let status = renderSilence(
            UnsafeMutableRawPointer(bitPattern: 1)!, &flags, &timestamp, 0, 64,
            abl.unsafeMutablePointer
        )

        #expect(status == noErr)
        expectAllZero(allocations[0], 256)
    }

    /// Integration: the DefaultOutput unit can be created and initialized with
    /// the callback installed. Does not start the unit, so it passes on
    /// headless CI runners and never produces audio or permission prompts.
    /// SetRenderCallback is write-only, so a successful return is the check.
    @Test func makeSilenceUnitInitializes() throws {
        let unit = try makeSilenceUnit()
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
    }
}
