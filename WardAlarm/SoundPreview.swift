import AVFoundation
import Combine
import Foundation

@MainActor
final class SoundPreview: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private var isCrescendo = false
    private var failureHandler: ((String) -> Void)?

    func play(onError: ((String) -> Void)? = nil) throws {
        stop()
        failureHandler = onError
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        do { try start(resource: "crescendo-alarm", loops: 0, crescendo: true) }
        catch { stop(); throw error }
    }

    private func start(resource: String, loops: Int, crescendo: Bool) throws {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            throw NSError(domain: "WardAlarm", code: 1, userInfo: [NSLocalizedDescriptionKey: "Het alarmgeluid ontbreekt."])
        }
        let next = try AVAudioPlayer(contentsOf: url)
        next.delegate = self
        next.numberOfLoops = loops
        next.prepareToPlay()
        guard next.play() else {
            throw NSError(domain: "WardAlarm", code: 2, userInfo: [NSLocalizedDescriptionKey: "Het geluid kon niet worden afgespeeld."])
        }
        player = next
        isCrescendo = crescendo
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        isCrescendo = false
        isPlaying = false
        failureHandler = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
        let finishedID = ObjectIdentifier(finished)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == finishedID else { return }
            if self.isCrescendo && flag {
                do { try self.start(resource: "windows-alarm", loops: -1, crescendo: false) }
                catch {
                    let callback = self.failureHandler
                    self.stop()
                    callback?("Het luide vervolg kon niet worden afgespeeld: \(error.localizedDescription)")
                }
            } else {
                self.stop()
            }
        }
    }
}
