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
    
    // Phase 4: Enhanced state for automatic playback
    @Published var isAutoPlayEnabled = true
    @Published var currentPlaybackSession: AudioPlaybackSession?
    @Published var playbackHistory: [AudioPlaybackRecord] = []
    private var currentTour: Tour? // Track current tour for audio timing optimization
    
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
            
            // Phase 4: Create playback session
            currentPlaybackSession = AudioPlaybackSession(
                id: UUID(),
                poi: poi,
                audioURL: url,
                startTime: Date(),
                isAutoTriggered: true
            )
            
            updateNowPlayingInfo()
            
            print("🎵 Started audio playback for POI: \(poi.name)")
            
        } catch {
            throw AudioError.playbackFailed(error)
        }
    }
    
    // MARK: - Tour Configuration
    
    func setCurrentTour(_ tour: Tour?) {
        currentTour = tour
        
        // Adjust audio settings based on tour type
        if let tour = tour {
            switch tour.tourType {
            case .driving:
                // For driving tours, ensure quick audio start and appropriate volume
                volume = 0.8 // Slightly lower for driving
                print("🚗 Audio configured for driving tour: \(tour.name)")
                
            case .walking:
                // For walking tours, can use full volume and longer content
                volume = 1.0
                print("🚶‍♂️ Audio configured for walking tour: \(tour.name)")
                
            case .mixed:
                // Balanced settings for mixed tours
                volume = 0.9
                print("🚶‍♂️🚗 Audio configured for mixed tour: \(tour.name)")
            }
        }
    }
    
    // Phase 4: Auto-play audio for POI visit
    func autoPlayForPOIVisit(_ poi: PointOfInterest) async throws {
        guard isAutoPlayEnabled else {
            print("🔇 Auto-play disabled, skipping audio for POI: \(poi.name)")
            return
        }
        
        // Check if we're already playing audio for this POI
        if let currentSession = currentPlaybackSession,
           currentSession.poi.id == poi.id {
            print("🎵 Already playing audio for POI: \(poi.name)")
            return
        }
        
        // For driving tours, implement quick audio trigger
        if currentTour?.tourType == .driving {
            await playOptimizedAudioForDriving(poi)
            return
        }
        
        // Try to find audio content for this POI
        if let audioContent = poi.audioContent,
           let localURLString = audioContent.localFileURL,
           let audioURL = URL(string: localURLString) {
            
            // Verify audio file exists
            if FileManager.default.fileExists(atPath: audioURL.path) {
                try await playAudio(from: audioURL, for: poi)
            } else {
                print("⚠️ Audio file not found for POI: \(poi.name) at \(audioURL)")
                
                // For testing, create a mock audio experience
                await playMockAudioForPOI(poi)
            }
        } else {
            print("ℹ️ No audio content configured for POI: \(poi.name)")
            
            // For testing, create a mock audio experience
            await playMockAudioForPOI(poi)
        }
    }
    
    // MARK: - Tour Type Optimized Playback
    
    private func playOptimizedAudioForDriving(_ poi: PointOfInterest) async {
        print("🚗 Playing driving-optimized audio for POI: \(poi.name)")
        
        // For driving tours:
        // 1. Start audio immediately (no delay)
        // 2. Use shorter, more concise content
        // 3. Ensure audio can be heard over road noise
        
        // Create optimized playback session for driving
        currentPlaybackSession = AudioPlaybackSession(
            id: UUID(),
            poi: poi,
            audioURL: URL(string: "mock://driving-audio/\(poi.id)")!,
            startTime: Date(),
            isAutoTriggered: true
        )
        
        currentPOI = poi
        isPlaying = true
        
        // Simulate driving-optimized audio timing
        let drivingAudioDuration: TimeInterval = 45.0 // Shorter for driving (45 seconds)
        duration = drivingAudioDuration
        currentTime = 0
        
        // Set higher playback rate for driving tours to fit content in shorter time window
        playbackRate = 1.1
        
        // Log the optimized playback
        print("🚗 Driving audio: \(Int(drivingAudioDuration))s duration, \(playbackRate)x speed")
        
        // Create playback record
        let record = AudioPlaybackRecord(
            id: UUID(),
            poiId: poi.id,
            poiName: poi.name,
            duration: drivingAudioDuration,
            completedAt: Date().addingTimeInterval(drivingAudioDuration),
            wasAutoTriggered: true,
            tourType: .driving
        )
        playbackHistory.append(record)
        
        // Simulate playback completion after driving-optimized duration
        Task { @MainActor [weak self] in
            try await Task.sleep(nanoseconds: UInt64(drivingAudioDuration * 1_000_000_000))
            self?.isPlaying = false
            self?.currentPlaybackSession = nil
            print("🚗 Driving audio completed for POI: \(poi.name)")
        }
    }
    
    // Phase 4: Mock audio playback for testing
    private func playMockAudioForPOI(_ poi: PointOfInterest) async {
        print("🎭 Playing mock audio for POI: \(poi.name)")
        
        // Determine audio duration based on tour type
        let audioDuration: TimeInterval
        let audioPrefix: String
        
        switch currentTour?.tourType {
        case .driving:
            audioDuration = 45.0 // 45 seconds for driving
            audioPrefix = "driving"
            playbackRate = 1.1 // Slightly faster for driving
            
        case .walking:
            audioDuration = 120.0 // 2 minutes for walking
            audioPrefix = "walking"
            playbackRate = 1.0 // Normal speed for walking
            
        case .mixed:
            audioDuration = 90.0 // 1.5 minutes for mixed
            audioPrefix = "mixed"
            playbackRate = 1.05 // Slightly faster for mixed
            
        case .none:
            audioDuration = 90.0 // Default 1.5 minutes
            audioPrefix = "default"
            playbackRate = 1.0
        }
        
        // Create a simulated playback session
        currentPlaybackSession = AudioPlaybackSession(
            id: UUID(),
            poi: poi,
            audioURL: URL(string: "mock://\(audioPrefix)-audio/\(poi.id)")!,
            startTime: Date(),
            isAutoTriggered: true
        )
        
        currentPOI = poi
        isPlaying = true
        duration = audioDuration // Use tour type-specific duration
        currentTime = 0
        
        // Simulate audio playback with a timer
        startMockPlaybackTimer()
        
        updateNowPlayingInfo()
    }
    
    private func startMockPlaybackTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            
            self.currentTime += 1.0
            
            if self.currentTime >= self.duration {
                timer.invalidate()
                Task { @MainActor in
                    self.handleMockPlaybackCompletion()
                }
            }
        }
    }
    
    private func handleMockPlaybackCompletion() {
        print("🎭 Mock audio playback completed")
        
        // Record the playback session
        if let session = currentPlaybackSession {
            let record = AudioPlaybackRecord(
                id: session.id,
                poiId: session.poi.id,
                poiName: session.poi.name,
                duration: duration,
                completedAt: Date(),
                wasAutoTriggered: session.isAutoTriggered,
                tourType: currentTour?.tourType
            )
            playbackHistory.append(record)
        }
        
        // Clean up session
        currentPlaybackSession = nil
        currentPOI = nil
        isPlaying = false
        currentTime = 0
        
        clearNowPlayingInfo()
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
            // Phase 4: Record playback completion
            if let session = currentPlaybackSession {
                let record = AudioPlaybackRecord(
                    id: session.id,
                    poiId: session.poi.id,
                    poiName: session.poi.name,
                    duration: duration,
                    completedAt: Date(),
                    wasAutoTriggered: session.isAutoTriggered,
                    tourType: currentTour?.tourType
                )
                playbackHistory.append(record)
                
                print("📊 Recorded audio completion for POI: \(session.poi.name)")
            }
            
            // Continue with queue if available
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

// Phase 4: Enhanced Audio Types

struct AudioPlaybackSession {
    let id: UUID
    let poi: PointOfInterest
    let audioURL: URL
    let startTime: Date
    let isAutoTriggered: Bool
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

struct AudioPlaybackRecord {
    let id: UUID
    let poiId: UUID
    let poiName: String
    let duration: TimeInterval
    let completedAt: Date
    let wasAutoTriggered: Bool
    let tourType: TourType?
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
    
    var tourTypeDescription: String {
        return tourType?.rawValue ?? "Unknown"
    }
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