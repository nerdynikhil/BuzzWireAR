import Foundation
import AVFoundation

class SoundManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine = AVAudioEngine()
    private var buzzToneGenerator = AVAudioPlayerNode()
    private var successToneGenerator = AVAudioPlayerNode()
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioEngine.attach(buzzToneGenerator)
            audioEngine.attach(successToneGenerator)
            audioEngine.connect(buzzToneGenerator, to: audioEngine.mainMixerNode, format: nil)
            audioEngine.connect(successToneGenerator, to: audioEngine.mainMixerNode, format: nil)
            
            try audioEngine.start()
        } catch {
            print("Failed to setup audio: \(error)")
        }
    }
    
    func playBuzzSound() {
        playTone(frequency: 200, duration: 0.3, volume: 0.7)
    }
    
    func playSuccessSound() {
        playTone(frequency: 523, duration: 0.5, volume: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 659, duration: 0.5, volume: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playTone(frequency: 784, duration: 0.7, volume: 0.6)
        }
    }
    
    private func playTone(frequency: Float, duration: TimeInterval, volume: Float) {
        let sampleRate: Float = 44100
        let length = Int(sampleRate * Float(duration))
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1) else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length)) else { return }
        
        buffer.frameLength = AVAudioFrameCount(length)
        
        let floatChannelData = buffer.floatChannelData![0]
        let omega = 2.0 * Float.pi * frequency / sampleRate
        
        for i in 0..<length {
            let sample = sin(omega * Float(i)) * volume
            floatChannelData[i] = sample * (1.0 - Float(i) / Float(length))
        }
        
        buzzToneGenerator.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !buzzToneGenerator.isPlaying {
            buzzToneGenerator.play()
        }
    }
}