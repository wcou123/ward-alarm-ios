import AVFoundation
import Combine
import Foundation

@MainActor
final class SoundPreview: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?

    func play() throws {
        stop()
        guard let url = Bundle.main.url(forResource: "windows-alarm", withExtension: "wav") else {
            throw NSError(domain: "WardAlarm", code: 1, userInfo: [NSLocalizedDescriptionKey: "Het alarmgeluid ontbreekt."])
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        do {
            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.delegate = self
            nextPlayer.numberOfLoops = 0
            nextPlayer.prepareToPlay()
            guard nextPlayer.play() else {
                throw NSError(domain: "WardAlarm", code: 2, userInfo: [NSLocalizedDescriptionKey: "Het geluid kon niet worden afgespeeld."])
            }
            player = nextPlayer
            isPlaying = true
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.stop() }
    }
}
