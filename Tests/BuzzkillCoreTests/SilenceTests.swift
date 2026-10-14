import AudioToolbox
import XCTest
@testable import BuzzkillCore

final class SilenceTests: XCTestCase {
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

    private func assertAllZero(_ data: UnsafeMutableRawPointer, _ count: Int,
                               file: StaticString = #filePath, line: UInt = #line) {
        let bytes = data.bindMemory(to: UInt8.self, capacity: count)
        for i in 0..<count {
            if bytes[i] != 0 {
                XCTFail("byte \(i) is \(bytes[i]), expected 0", file: file, line: line)
                return
            }
        }
    }

    func testZeroBuffersZeroesSingleBuffer() {
        let (abl, allocations) = makeDirtyBufferList(buffers: 1, bytesPerBuffer: 4096)
        defer { allocations.forEach { $0.deallocate() }; free(abl.unsafeMutablePointer) }

        zeroBuffers(abl.unsafeMutablePointer)
        assertAllZero(allocations[0], 4096)
    }

    func testZeroBuffersZeroesAllBuffersInList() {
        let (abl, allocations) = makeDirtyBufferList(buffers: 3, bytesPerBuffer: 512)
        defer { allocations.forEach { $0.deallocate() }; free(abl.unsafeMutablePointer) }

        zeroBuffers(abl.unsafeMutablePointer)
        for data in allocations {
            assertAllZero(data, 512)
        }
    }

    func testZeroBuffersHandlesNilListAndNilData() {
        zeroBuffers(nil) // must not crash

        let abl = AudioBufferList.allocate(maximumBuffers: 1)
        defer { free(abl.unsafeMutablePointer) }
        abl[0] = AudioBuffer(mNumberChannels: 2, mDataByteSize: 1024, mData: nil)
        zeroBuffers(abl.unsafeMutablePointer) // must not crash
    }

    func testRenderCallbackReturnsNoErrAndZeroes() {
        let (abl, allocations) = makeDirtyBufferList(buffers: 1, bytesPerBuffer: 256)
        defer { allocations.forEach { $0.deallocate() }; free(abl.unsafeMutablePointer) }

        var flags = AudioUnitRenderActionFlags()
        var timestamp = AudioTimeStamp()
        let status = renderSilence(
            UnsafeMutableRawPointer(bitPattern: 1)!, &flags, &timestamp, 0, 64,
            abl.unsafeMutablePointer
        )

        XCTAssertEqual(status, noErr)
        assertAllZero(allocations[0], 256)
    }

    /// Integration: the DefaultOutput unit can be created and initialized with
    /// the callback installed. Does not start the unit, so it passes on
    /// headless CI runners and never produces audio or permission prompts.
    func testMakeSilenceUnitInitializes() throws {
        let unit = try makeSilenceUnit()
        defer {
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }

        var callback = AURenderCallbackStruct()
        var size = UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        let status = AudioUnitGetProperty(
            unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
            &callback, &size
        )
        XCTAssertEqual(status, noErr)
        XCTAssertNotNil(callback.inputProc)
    }
}
