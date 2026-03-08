import AVFoundation

final class KanaSpeaker {
    static let shared = KanaSpeaker()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }

    func speak(_ text: String, times: Int = 1) {
        synthesizer.stopSpeaking(at: .immediate)
        for i in 0..<max(1, times) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
            utterance.rate = 0.38
            utterance.pitchMultiplier = 1.15
            utterance.volume = 1.0
            if i < times - 1 {
                utterance.postUtteranceDelay = 0.5
            }
            synthesizer.speak(utterance)
        }
    }
}
