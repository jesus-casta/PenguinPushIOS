import SwiftUI
import AVFoundation

@main
struct PenguinPushApp: App {
    init() {
        // Respect silent mode and let the user's own music continue playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    }
    var body: some Scene {
        WindowGroup {
            GameView()
                .background(Color(red: 0.918, green: 0.957, blue: 0.973))
        }
    }
}
