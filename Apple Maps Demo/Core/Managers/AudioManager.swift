import AVFoundation
import MediaPlayer
import Combine

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var queuePlayer: AVQueuePlayer?
    private var audioSession: AVAudioSession
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentPOI: PointOfInterest?
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 1.0
    
    private var timeObserver: Any?
    private var audioQueue: [AudioQueueItem] = []
    private var currentQueueIndex = 0
    
    override private init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playAudio(from url: URL, for poi: PointOfInterest) async throws {
        currentPOI = poi
        
        // Setup audio session only when needed
        setupAudioSession()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.volume = volume
            
            duration = audioPlayer?.duration ?? 0
            
            audioPlayer?.play()
            isPlaying = true
            
            updateNowPlayingInfo()
            
        } catch {
            throw AudioError.playbackFailed(error)
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        currentPOI = nil
        clearNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }
    
    func skipForward(_ seconds: TimeInterval = 30) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval = 30) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
    }
    
    func setVolume(_ volume: Float) {
        self.volume = volume
        audioPlayer?.volume = volume
    }
    
    // MARK: - Queue Management
    
    func queueAudio(_ items: [AudioQueueItem]) {
        audioQueue = items
        currentQueueIndex = 0
        playNextInQueue()
    }
    
    private func playNextInQueue() {
        guard currentQueueIndex < audioQueue.count else {
            stop()
            return
        }
        
        let item = audioQueue[currentQueueIndex]
        Task {
            try? await playAudio(from: item.url, for: item.poi)
        }
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        
        info[MPMediaItemPropertyTitle] = currentPOI?.name ?? "Audio Tour"
        info[MPMediaItemPropertyArtist] = "Audio Tours"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Remote Command Center
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            currentQueueIndex += 1
            playNextInQueue()
        } else {
            stop()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        stop()
    }
}

// MARK: - Supporting Types

struct AudioQueueItem {
    let url: URL
    let poi: PointOfInterest
}

enum AudioError: LocalizedError {
    case playbackFailed(Error)
    case fileNotFound
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidFormat:
            return "Invalid audio format"
        }
    }
}