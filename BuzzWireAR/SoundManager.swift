import Foundation
import AVFoundation
import Combine

@MainActor
class SoundManager: ObservableObject {
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio: \(error)")
        }
    }
    
    func playBuzzSound() {
        print("🔊 BUZZ!")
        // Just print for now - sound was causing crash
    }
    
    func playSuccessSound() {
        print("🎉 SUCCESS!")
        // Just print for now - sound was causing crash
    }
}