import Foundation

/// Minimal RIFF/WAVE read/write for 16 kHz mono 16-bit PCM — the format
/// shared by the recorder, the saved-recordings corpus, and the regression
/// harness fixtures. The reader walks the chunk list properly instead of
/// assuming a 44-byte header.
public enum WavIO {
    public enum Error: Swift.Error, CustomStringConvertible {
        case malformed(String)
        public var description: String {
            if case .malformed(let why) = self { return "malformed wav: \(why)" }
            return "malformed wav"
        }
    }

    public static func readMono16k(_ url: URL) throws -> [Float] {
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

    /// Writes 16 kHz mono 16-bit PCM. Float samples are clamped to ±1.
    public static func writeMono16k(_ samples: [Float], to url: URL) throws {
        var pcm = Data(capacity: samples.count * 2)
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * 32767)
            withUnsafeBytes(of: v.littleEndian) { pcm.append(contentsOf: $0) }
        }
        var data = Data()
        func ascii(_ s: String) { data.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + pcm.count)); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1)          // PCM, mono
        u32(16_000); u32(16_000 * 2); u16(2); u16(16)   // rate, bytes/s, align, bits
        ascii("data"); u32(UInt32(pcm.count))
        data.append(pcm)
        try data.write(to: url)
    }

    private static func readU32(_ d: Data, _ at: Int) -> UInt32 {
        d.subdata(in: at..<at + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }
    private static func readU16(_ d: Data, _ at: Int) -> UInt16 {
        d.subdata(in: at..<at + 2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian
    }
}
