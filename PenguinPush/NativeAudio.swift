import AVFoundation

final class NativeAudio {
    enum Effect: CaseIterable { case step, push, goal, blocked, undo, win }
    private var players: [Effect: AVAudioPlayer] = [:]
    init() {
        for effect in Effect.allCases {
            if let player = try? AVAudioPlayer(data: Self.wave(effect)) { player.prepareToPlay(); players[effect] = player }
        }
    }
    func play(_ effect: Effect, volume: Float) {
        guard let player = players[effect] else { return }
        player.stop(); player.currentTime = 0; player.volume = min(1, max(0, volume)); player.play()
    }
    func pause() { players.values.forEach { $0.stop() } }
    private static func wave(_ effect: Effect) -> Data {
        let notes: [(Double, Double)]
        switch effect {
        case .step: notes = [(180, 0.055)]
        case .push: notes = [(95, 0.10)]
        case .blocked: notes = [(120, 0.065)]
        case .undo: notes = [(480, 0.10)]
        case .goal: notes = [(660, 0.10), (880, 0.16)]
        case .win: notes = [(523.25, 0.11), (659.25, 0.11), (783.99, 0.11), (1046.5, 0.25)]
        }
        let rate: Double = 22050
        var samples: [Int16] = []
        for (frequency, duration) in notes {
            for i in 0..<Int(rate * duration) {
                let t = Double(i) / rate, envelope = min(1, t / 0.006) * max(0, 1 - t / duration)
                samples.append(Int16(sin(2 * .pi * frequency * t) * envelope * 14000))
            }
        }
        var data = Data()
        func ascii(_ text: String) { data.append(contentsOf: text.utf8) }
        func u32(_ value: UInt32) { var le = value.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var le = value.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + samples.count * 2)); ascii("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16); ascii("data"); u32(UInt32(samples.count * 2))
        for sample in samples { u16(UInt16(bitPattern: sample)) }
        return data
    }
}
