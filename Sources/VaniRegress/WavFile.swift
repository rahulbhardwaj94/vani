import Foundation

/// Minimal RIFF/WAVE reader for the harness fixtures: 16 kHz mono 16-bit
/// PCM (what scripts/gen-fixtures.sh emits via afconvert). Walks the chunk
/// list properly instead of assuming a 44-byte header.
enum WavFile {
    enum Error: Swift.Error, CustomStringConvertible {
        case malformed(String)
        var description: String {
            if case .malformed(let why) = self { return "malformed wav: \(why)" }
            return "malformed wav"
        }
    }

    static func readMono16k(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        guard data.count > 44,
              String(data: data[0..<4], encoding: .ascii) == "RIFF",
              String(data: data[8..<12], encoding: .ascii) == "WAVE" else {
            throw Error.malformed("not RIFF/WAVE")
        }

        var offset = 12
        var sampleRate = 0
        var channels = 0
        var bits = 0
        var pcm: Data?
        while offset + 8 <= data.count {
            let id = String(data: data[offset..<offset + 4], encoding: .ascii) ?? ""
            let size = Int(readU32(data, offset + 4))
            let body = offset + 8
            if id == "fmt ", body + 16 <= data.count {
                channels = Int(readU16(data, body + 2))
                sampleRate = Int(readU32(data, body + 4))
                bits = Int(readU16(data, body + 14))
            } else if id == "data", body + size <= data.count {
                pcm = data.subdata(in: body..<body + size)
            }
            offset = body + size + (size % 2) // chunks are word-aligned
        }

        guard let pcm else { throw Error.malformed("no data chunk") }
        guard sampleRate == 16_000, channels == 1, bits == 16 else {
            throw Error.malformed("need 16 kHz mono 16-bit, got \(sampleRate) Hz \(channels)ch \(bits)-bit")
        }
        var samples = [Float](repeating: 0, count: pcm.count / 2)
        pcm.withUnsafeBytes { raw in
            let int16 = raw.bindMemory(to: Int16.self)
            for i in 0..<samples.count {
                samples[i] = Float(Int16(littleEndian: int16[i])) / 32768.0
            }
        }
        return samples
    }

    private static func readU32(_ d: Data, _ at: Int) -> UInt32 {
        d.subdata(in: at..<at + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }
    private static func readU16(_ d: Data, _ at: Int) -> UInt16 {
        d.subdata(in: at..<at + 2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian
    }
}
