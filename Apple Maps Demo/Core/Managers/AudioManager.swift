@preconcurrency import AVFoundation
@preconcurrency import MediaPlayer
import Combine
import UIKit
import QuartzCore // For CACurrentMediaTime

// MARK: - AudioManager

@MainActor
final class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager(audioStorageService: nil, dataService: nil)
    
    // MARK: - Audio Players (Dual System for Crossfading)
    private var primaryPlayer: AVAudioPlayer?
    private var secondaryPlayer: AVAudioPlayer?
    private var activePlayer: PlayerInstance = .primary
    private var queuePlayer: AVQueuePlayer?
    private var audioSession: AVAudioSession
    
    // MARK: - Published State
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentPOI: PointOfInterest?
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 1.0
    @Published var isCrossfading = false
    @Published var isBuffering = false
    @Published var audioQuality: AudioQuality = .medium
    @Published var connectionStatus: AudioConnectionStatus = .builtin
    
    // Phase 4: Enhanced state for automatic playback
    @Published var isAutoPlayEnabled = true
    @Published var currentPlaybackSession: AudioPlaybackSession?
    @Published var playbackHistory: [AudioPlaybackRecord] = []
    
    // Phase 5: Professional Audio Engine State
    @Published var audioRoute: AudioRoute = .builtin
    @Published var isExternalAudioConnected = false
    @Published var currentAudioSession: AudioSessionState = .inactive
    
    // MARK: - Private State
    private var currentTour: Tour?
    private var timeObserver: Any?
    private var audioQueue: [AudioQueueItem] = []
    private var currentQueueIndex = 0
    
    // Timers/contexts (selector-based to avoid @Sendable captures)
    private var crossfadeTimer: Timer?
    private var crossfadeContext: CrossfadeContext?
    private var mockTimer: Timer?
    
    private var audioSessionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    
    // MARK: - Dependencies
    private let audioStorageService: AudioStorageService
    private let dataService: DataService
    
    // MARK: - Predictive Loading
    private var predictiveQueue: [AudioQueueItem] = []
    private var preloadedContent: [UUID: AudioContent] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init / Deinit
    
    init(
        audioStorageService: AudioStorageService? = nil,
        dataService: DataService? = nil
    ) {
        self.audioSession = AVAudioSession.sharedInstance()
        self.audioStorageService = audioStorageService ?? AudioStorageService.shared
        self.dataService = dataService ?? DataService.shared
        super.init()
        
        Task { @MainActor in
            await setupProfessionalAudioSession()
            await setupRemoteCommandCenter()
            await setupAudioSessionObservers()
            await setupPredictiveLoading()
        }
    }
    
    deinit {
        crossfadeTimer?.invalidate()
        mockTimer?.invalidate()
        if let obs = audioSessionObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = routeChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
    
    // MARK: - Professional Audio Session Configuration
    
    private func setupProfessionalAudioSession() async {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [
                    .mixWithOthers,
                    .duckOthers,
                    .allowBluetooth,
                    .allowAirPlay,
                    .defaultToSpeaker
                ]
            )
            try audioSession.setPreferredSampleRate(44100.0)   // CD quality
            try audioSession.setPreferredIOBufferDuration(0.02) // 20ms buffer
            try audioSession.setActive(true)
            
            await updateAudioRoute()
            currentAudioSession = .active
            print("✅ Professional audio session configured successfully")
        } catch {
            print("❌ Failed to setup professional audio session: \(error)")
            currentAudioSession = .error(error.localizedDescription)
        }
    }
    
    private func setupAudioSessionObservers() async {
        audioSessionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                await self.handleAudioSessionInterruption(notification)
            }
        }
        
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                await self.handleAudioRouteChange(notification)
            }
        }
    }
    
    private func handleAudioSessionInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 Audio interruption began - pausing playback")
            pause()
            currentAudioSession = .interrupted
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                print("🔊 Audio interruption ended - resuming playback")
                currentAudioSession = .active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.resume()
                }
            } else {
                print("🔇 Audio interruption ended - manual resume required")
                currentAudioSession = .inactive
            }
            
        @unknown default:
            print("⚠️ Unknown audio interruption type: \(type)")
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        await updateAudioRoute()
        
        switch reason {
        case .newDeviceAvailable:
            print("🎧 New audio device connected: \(audioRoute.description)")
            isExternalAudioConnected = audioRoute != .builtin
        case .oldDeviceUnavailable:
            print("🔌 Audio device disconnected")
            isExternalAudioConnected = false
            if audioRoute == .builtin { pause() }
        case .categoryChange:
            print("📂 Audio category changed")
        case .override:
            print("🔄 Audio route override")
        case .wakeFromSleep:
            print("😴 Audio session wake from sleep")
        case .noSuitableRouteForCategory:
            print("❌ No suitable audio route available")
        case .routeConfigurationChange:
            print("⚙️ Audio route configuration changed")
        case .unknown:
            print("⚠️ Unknown audio route change reason")
        @unknown default:
            print("⚠️ Future audio route change reason: \(reason)")
        }
    }
    
    private func updateAudioRoute() async {
        let currentRoute = audioSession.currentRoute
        if currentRoute.outputs.contains(where: { $0.portType == .carAudio }) {
            audioRoute = .carPlay
            connectionStatus = .carPlay
        } else if currentRoute.outputs.contains(where: { $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP }) {
            audioRoute = .bluetooth
            connectionStatus = .bluetooth
        } else if currentRoute.outputs.contains(where: { $0.portType == .headphones || $0.portType == .headsetMic }) {
            audioRoute = .headphones
            connectionStatus = .headphones
        } else if currentRoute.outputs.contains(where: { $0.portType == .airPlay }) {
            audioRoute = .airPlay
            connectionStatus = .airPlay
        } else {
            audioRoute = .builtin
            connectionStatus = .builtin
        }
        print("🔊 Audio route updated: \(audioRoute.description)")
    }
    
    // MARK: - Predictive Loading Setup
    
    private func setupPredictiveLoading() async {
        audioStorageService.downloadProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleDownloadProgress(progress)
                }
            }
            .store(in: &cancellables)
        
        audioStorageService.cacheUpdates
            .receive(on: RunLoop.main)
            .sink { [weak self] update in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleCacheUpdate(update)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleDownloadProgress(_ progress: DownloadProgress) async {
        print("📥 Download progress for \(progress.contentId): \(progress.formattedProgress)")
    }
    
    private func handleCacheUpdate(_ update: CacheUpdate) async {
        switch update {
        case .downloadCompleted(let contentId):
            print("✅ Download completed for content: \(contentId)")
            if let queueItem = predictiveQueue.first(where: { $0.poi.id == contentId }) {
                print("🎯 Predictively loaded content ready: \(queueItem.poi.name)")
            }
        case .downloadFailed(let contentId, let error):
            print("❌ Download failed for content: \(contentId) - \(error)")
        case .fileDeleted(let contentId):
            preloadedContent.removeValue(forKey: contentId)
        case .cacheCleared(let deletedFiles, let freedSpace):
            print("🧹 Cache cleared: \(deletedFiles) files, \(ByteCountFormatter().string(fromByteCount: freedSpace)) freed")
            preloadedContent.removeAll()
        case .cacheOptimized(let deletedFiles, let freedSpace):
            print("⚡ Cache optimized: \(deletedFiles) files removed, \(ByteCountFormatter().string(fromByteCount: freedSpace)) freed")
        @unknown default:
            break
        }
    }
    
    // MARK: - Player Management
    
    private func getCurrentPlayer() -> AVAudioPlayer? {
        return activePlayer == .primary ? primaryPlayer : secondaryPlayer
    }
    private func getInactivePlayer() -> AVAudioPlayer? {
        return activePlayer == .primary ? secondaryPlayer : primaryPlayer
    }
    private func switchActivePlayer() {
        activePlayer = activePlayer == .primary ? .secondary : .primary
    }
    
    // MARK: - Enhanced Audio Playback
    
    @MainActor func playAudio(from url: URL, for poi: PointOfInterest) async throws {
        currentPOI = poi
        isBuffering = true
        
        if currentAudioSession != .active { await setupProfessionalAudioSession() }
        
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.enableRate = true
            newPlayer.rate = playbackRate
            newPlayer.volume = volume
            
            if activePlayer == .primary { secondaryPlayer = newPlayer } else { primaryPlayer = newPlayer }
            
            duration = newPlayer.duration
            isBuffering = false
            
            if isPlaying {
                performCrossfade(to: newPlayer) // non-async now
            } else {
                switchActivePlayer()
                newPlayer.play()
                isPlaying = true
            }
            
            currentPlaybackSession = AudioPlaybackSession(
                id: UUID(),
                poi: poi,
                audioURL: url,
                startTime: Date(),
                isAutoTriggered: true
            )
            
            await updateNowPlayingInfo()
            await triggerPredictiveLoading(currentPOI: poi)
            print("🎵 Started audio playback for POI: \(poi.name)")
        } catch {
            isBuffering = false
            throw AudioError.playbackFailed(error)
        }
    }
    
    // MARK: - Smart Audio Loading
    
    @MainActor func playAudioForPOI(_ poi: PointOfInterest) async throws {
        let audioContent = try await getOrCreateAudioContent(for: poi)
        if audioStorageService.isFileAvailable(for: audioContent) {
            let localURL = audioStorageService.getLocalURL(for: audioContent)
            try await playAudio(from: localURL, for: poi)
            audioContent.recordPlayback()
            try await dataService.audioRepository.save(audioContent)
        } else {
            print("📥 Audio not cached for POI: \(poi.name), initiating download")
            try await audioStorageService.downloadAudio(audioContent, priority: .critical)
            await playMockAudioForPOI(poi)
        }
    }
    
    private func getOrCreateAudioContent(for poi: PointOfInterest) async throws -> AudioContent {
        if let list = try? await dataService.audioRepository.fetchByPOI(poi.id),
           let existing = list.first {
            return existing
        }
        let audioContent = AudioContent(
            poiId: poi.id,
            duration: 0,
            language: "en",
            isLLMGenerated: false
        )
        if let audioURL = poi.audioContent?.remoteURL {
            audioContent.remoteURL = audioURL
        }
        try await dataService.audioRepository.save(audioContent)
        return audioContent
    }
    
    // MARK: - Predictive Loading
    
    private func triggerPredictiveLoading(currentPOI: PointOfInterest) async {
        guard let tour = currentTour else { return }
        do {
            let tourPOIs = try await dataService.poiRepository.fetchByTour(tour.id)
            let upcomingPOIs = getUpcomingPOIs(from: tourPOIs, current: currentPOI, count: 3)
            for poi in upcomingPOIs {
                await predictivelyLoadPOI(poi)
            }
        } catch {
            print("❌ Failed to trigger predictive loading: \(error)")
        }
    }
    
    private func getUpcomingPOIs(from allPOIs: [PointOfInterest], current: PointOfInterest, count: Int) -> [PointOfInterest] {
        let sortedPOIs = allPOIs.sorted { $0.order < $1.order }
        guard let currentIndex = sortedPOIs.firstIndex(where: { $0.id == current.id }) else {
            return Array(sortedPOIs.prefix(count))
        }
        let nextIndex = currentIndex + 1
        let endIndex = min(nextIndex + count, sortedPOIs.count)
        return Array(sortedPOIs[nextIndex..<endIndex])
    }
    
    private func predictivelyLoadPOI(_ poi: PointOfInterest) async {
        do {
            let audioContent = try await getOrCreateAudioContent(for: poi)
            guard !audioStorageService.isFileAvailable(for: audioContent) else {
                print("✅ POI \(poi.name) already cached"); return
            }
            if audioStorageService.activeDownloads[audioContent.id] != nil {
                print("📥 POI \(poi.name) already downloading"); return
            }
            try await audioStorageService.downloadAudio(audioContent, priority: .normal)
            print("🎯 Started predictive download for POI: \(poi.name)")
        } catch {
            print("❌ Failed to predictively load POI \(poi.name): \(error)")
        }
    }
    
    // MARK: - Tour Management Enhancement
    
    func startTourWithPreloading(_ tour: Tour) async throws {
        setCurrentTour(tour)
        let strategy: PreloadStrategy
        switch tour.tourType {
        case .driving: strategy = .priorityOnly
        case .walking: strategy = .nextThree
        case .mixed:   strategy = .priorityOnly
        @unknown default: strategy = .priorityOnly
        }
        await audioStorageService.preloadTourAudio(tourId: tour.id, strategy: strategy)
        print("🎯 Started tour with preloading strategy: \(strategy)")
    }
    
    // MARK: - Professional Crossfading (selector-based timer)
    
    private func performCrossfade(to newPlayer: AVAudioPlayer) {
        isCrossfading = true
        let crossfadeDuration: TimeInterval = 2.0
        let oldPlayer = getCurrentPlayer()
        
        print("🎵 Starting crossfade transition")
        
        newPlayer.volume = 0.0
        newPlayer.play()
        switchActivePlayer()
        
        let ctx = CrossfadeContext(old: oldPlayer, new: newPlayer, duration: crossfadeDuration)
        crossfadeContext = ctx
        
        crossfadeTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(handleCrossfadeTick), userInfo: nil, repeats: true)
        crossfadeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc private func handleCrossfadeTick() {
        guard let ctx = crossfadeContext else { return }
        let elapsed = CACurrentMediaTime() - ctx.startTime
        let progress = max(0.0, min(1.0, elapsed / ctx.duration))
        ctx.oldPlayer?.volume = Float((1.0 - progress)) * volume
        ctx.newPlayer?.volume = Float(progress) * volume
        if progress >= 1.0 {
            ctx.oldPlayer?.stop()
            ctx.newPlayer?.volume = volume
            isCrossfading = false
            crossfadeTimer?.invalidate()
            crossfadeTimer = nil
            crossfadeContext = nil
            print("✅ Crossfade transition completed")
        }
    }
    
    // MARK: - Tour Configuration
    
    func setCurrentTour(_ tour: Tour?) {
        currentTour = tour
        if let tour = tour {
            switch tour.tourType {
            case .driving:
                volume = 0.8
                print("🚗 Audio configured for driving tour: \(tour.name)")
            case .walking:
                volume = 1.0
                print("🚶‍♂️ Audio configured for walking tour: \(tour.name)")
            case .mixed:
                volume = 0.9
                print("🚶‍♂️🚗 Audio configured for mixed tour: \(tour.name)")
            @unknown default:
                volume = 0.9
                print("ℹ️ Audio configured for unknown tour type: \(tour.name)")
            }
        }
    }
    
    // Phase 4: Auto-play audio for POI visit
    func autoPlayForPOIVisit(_ poi: PointOfInterest) async throws {
        guard isAutoPlayEnabled else {
            print("🔇 Auto-play disabled, skipping audio for POI: \(poi.name)")
            return
        }
        if let currentSession = currentPlaybackSession, currentSession.poi.id == poi.id {
            print("🎵 Already playing audio for POI: \(poi.name)")
            return
        }
        try await playAudioForPOI(poi)
    }
}

// MARK: - Tour Type Optimized Playback Extensions

extension AudioManager {
    private func playOptimizedAudioForDriving(_ poi: PointOfInterest) async {
        print("🚗 Playing driving-optimized audio for POI: \(poi.name)")
        currentPlaybackSession = AudioPlaybackSession(
            id: UUID(),
            poi: poi,
            audioURL: URL(string: "mock://driving-audio/\(poi.id)")!,
            startTime: Date(),
            isAutoTriggered: true
        )
        currentPOI = poi
        isPlaying = true
        let drivingAudioDuration: TimeInterval = 45.0
        duration = drivingAudioDuration
        currentTime = 0
        playbackRate = 1.1
        print("🚗 Driving audio: \(Int(drivingAudioDuration))s duration, \(playbackRate)x speed")
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
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(drivingAudioDuration * 1_000_000_000))
            self?.isPlaying = false
            self?.currentPlaybackSession = nil
            print("🚗 Driving audio completed for POI: \(poi.name)")
        }
    }
    
    // Phase 4: Mock audio playback for testing (selector-based timer)
    private func playMockAudioForPOI(_ poi: PointOfInterest) async {
        print("🎭 Playing mock audio for POI: \(poi.name)")
        let audioDuration: TimeInterval
        let audioPrefix: String
        switch currentTour?.tourType {
        case .driving:
            audioDuration = 45.0; audioPrefix = "driving"; playbackRate = 1.1
        case .walking:
            audioDuration = 120.0; audioPrefix = "walking"; playbackRate = 1.0
        case .mixed:
            audioDuration = 90.0; audioPrefix = "mixed"; playbackRate = 1.05
        case .none:
            audioDuration = 90.0; audioPrefix = "default"; playbackRate = 1.0
        @unknown default:
            audioDuration = 90.0; audioPrefix = "default"; playbackRate = 1.0
        }
        currentPlaybackSession = AudioPlaybackSession(
            id: UUID(),
            poi: poi,
            audioURL: URL(string: "mock://\(audioPrefix)-audio/\(poi.id)")!,
            startTime: Date(),
            isAutoTriggered: true
        )
        currentPOI = poi
        isPlaying = true
        duration = audioDuration
        currentTime = 0
        
        mockTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(handleMockTick), userInfo: nil, repeats: true)
        mockTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        
        await updateNowPlayingInfo()
    }
    
    @objc private func handleMockTick() {
        guard isPlaying else {
            mockTimer?.invalidate(); mockTimer = nil
            return
        }
        currentTime += 1.0
        if currentTime >= duration {
            mockTimer?.invalidate(); mockTimer = nil
            Task { @MainActor in
                await self.handleMockPlaybackCompletion()
            }
        }
    }
    
    private func handleMockPlaybackCompletion() async {
        print("🎭 Mock audio playback completed")
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
        currentPlaybackSession = nil
        currentPOI = nil
        isPlaying = false
        currentTime = 0
        await clearNowPlayingInfo()
    }
    
    func pause() {
        crossfadeTimer?.invalidate(); crossfadeTimer = nil
        mockTimer?.invalidate(); mockTimer = nil
        getCurrentPlayer()?.pause()
        isPlaying = false
        isCrossfading = false
        Task { @MainActor in await updateNowPlayingInfo() }
        print("⏸️ Audio playback paused")
    }
    
    func resume() {
        guard let currentPlayer = getCurrentPlayer() else {
            print("❌ No active player to resume"); return
        }
        currentPlayer.play()
        isPlaying = true
        Task { @MainActor in await updateNowPlayingInfo() }
        print("▶️ Audio playback resumed")
    }
    
    func stop() {
        crossfadeTimer?.invalidate(); crossfadeTimer = nil
        mockTimer?.invalidate(); mockTimer = nil
        primaryPlayer?.stop()
        secondaryPlayer?.stop()
        primaryPlayer = nil
        secondaryPlayer = nil
        isPlaying = false
        isCrossfading = false
        isBuffering = false
        currentTime = 0
        currentPOI = nil
        currentPlaybackSession = nil
        Task { @MainActor in await clearNowPlayingInfo() }
        print("⏹️ Audio playback stopped")
    }
    
    func seek(to time: TimeInterval) {
        getCurrentPlayer()?.currentTime = time
        currentTime = time
        Task { @MainActor in await updateNowPlayingInfo() }
        print("⏭️ Seeked to \(Int(time))s")
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
        let clampedRate = max(0.5, min(2.0, rate))
        playbackRate = clampedRate
        primaryPlayer?.rate = clampedRate
        secondaryPlayer?.rate = clampedRate
        Task { @MainActor in await updateNowPlayingInfo() }
        print("🏃‍♂️ Playback rate set to \(clampedRate)x")
    }
    
    func setVolume(_ newVolume: Float) {
        let clampedVolume = max(0.0, min(1.0, newVolume))
        volume = clampedVolume
        if !isCrossfading {
            primaryPlayer?.volume = clampedVolume
            secondaryPlayer?.volume = clampedVolume
        }
        print("🔊 Volume set to \(Int(clampedVolume * 100))%")
    }
    
    // MARK: - Queue Management
    
    func queueAudio(_ items: [AudioQueueItem]) {
        audioQueue = items
        currentQueueIndex = 0
        playNextInQueue()
    }
    
    private func playNextInQueue() {
        guard currentQueueIndex < audioQueue.count else { stop(); return }
        let item = audioQueue[currentQueueIndex]
        Task { @MainActor in
            try? await playAudio(from: item.url, for: item.poi)
        }
    }
    
    // MARK: - Enhanced Now Playing Info
    
    private func updateNowPlayingInfo() async {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentPOI?.name ?? "Audio Tour"
        info[MPMediaItemPropertyArtist] = currentTour?.name ?? "Audio Tours"
        info[MPMediaItemPropertyAlbumTitle] = "Points of Interest"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        if currentPOI != nil {
            info[MPMediaItemPropertyComments] = currentPOI?.poiDescription
            if let tourType = currentTour?.tourType {
                info[MPMediaItemPropertyGenre] = "\(tourType.rawValue) Tour"
            }
            let qualityInfo = "Quality: \(audioQuality.description) • Route: \(audioRoute.description)"
            info[MPMediaItemPropertyAlbumArtist] = qualityInfo
        }
        if currentPOI != nil, let art = createDefaultArtwork() {
            info[MPMediaItemPropertyArtwork] = art
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        print("🎵 Updated Now Playing info for: \(currentPOI?.name ?? "Unknown")")
    }
    
    private func clearNowPlayingInfo() async {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        print("🔇 Cleared Now Playing info")
    }
    
    private func createDefaultArtwork() -> MPMediaItemArtwork? {
        let artworkSize = CGSize(width: 512, height: 512)
        return MPMediaItemArtwork(boundsSize: artworkSize) { size in
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            let iconSize: CGFloat = size.width * 0.4
            let iconRect = CGRect(x: (size.width - iconSize) / 2, y: (size.height - iconSize) / 2, width: iconSize, height: iconSize)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: iconRect).fill()
            return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }
    }
    
    // MARK: - Enhanced Remote Command Center
    
    private func setupRemoteCommandCenter() async {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in self?.stop(); return .success }
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 30)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 30.0
            self?.skipForward(interval); return .success
        }
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 30)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 30.0
            self?.skipBackward(interval); return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime); return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in self?.advanceToNextInQueue(); return .success }
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in self?.playPreviousInQueue(); return .success }
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            self?.setPlaybackRate(e.playbackRate); return .success
        }
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.addTarget { [weak self] _ in self?.likePOI(); return .success }
        commandCenter.dislikeCommand.isEnabled = true
        commandCenter.dislikeCommand.addTarget { [weak self] _ in self?.dislikePOI(); return .success }
        commandCenter.bookmarkCommand.isEnabled = true
        commandCenter.bookmarkCommand.addTarget { [weak self] _ in self?.bookmarkPOI(); return .success }
        print("✅ Enhanced remote command center configured")
    }
    
    // MARK: - Queue Navigation
    
    private func advanceToNextInQueue() {
        guard currentQueueIndex < audioQueue.count - 1 else {
            print("📻 Already at end of queue"); stop(); return
        }
        currentQueueIndex += 1
        playNextInQueue()
    }
    private func playPreviousInQueue() {
        guard currentQueueIndex > 0 else {
            print("📻 Already at beginning of queue"); return
        }
        currentQueueIndex -= 1
        playNextInQueue()
    }
    
    // MARK: - POI Interaction Commands
    
    private func likePOI() {
        guard let currentPOI = currentPOI else { return }
        print("👍 Liked POI: \(currentPOI.name)")
    }
    private func dislikePOI() {
        guard let currentPOI = currentPOI else { return }
        print("👎 Disliked POI: \(currentPOI.name)")
    }
    private func bookmarkPOI() {
        guard let currentPOI = currentPOI else { return }
        print("🔖 Bookmarked POI: \(currentPOI.name)")
    }
}

// MARK: - Crossfade Context (helper)

private final class CrossfadeContext {
    weak var oldPlayer: AVAudioPlayer?
    weak var newPlayer: AVAudioPlayer?
    let startTime: CFTimeInterval
    let duration: TimeInterval
    init(old: AVAudioPlayer?, new: AVAudioPlayer, duration: TimeInterval) {
        self.oldPlayer = old
        self.newPlayer = new
        self.duration = duration
        self.startTime = CACurrentMediaTime()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if flag {
                if let session = self.currentPlaybackSession {
                    let record = AudioPlaybackRecord(
                        id: session.id,
                        poiId: session.poi.id,
                        poiName: session.poi.name,
                        duration: self.duration,
                        completedAt: Date(),
                        wasAutoTriggered: session.isAutoTriggered,
                        tourType: self.currentTour?.tourType
                    )
                    self.playbackHistory.append(record)
                    print("📊 Recorded audio completion for POI: \(session.poi.name)")
                }
                self.currentQueueIndex += 1
                self.playNextInQueue()
            } else {
                self.stop()
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
            self?.stop()
        }
    }
}

// MARK: - Supporting Types

struct AudioQueueItem {
    let url: URL
    let poi: PointOfInterest
}

struct AudioPlaybackSession {
    let id: UUID
    let poi: PointOfInterest
    let audioURL: URL
    let startTime: Date
    let isAutoTriggered: Bool
    var duration: TimeInterval { Date().timeIntervalSince(startTime) }
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
        tourType?.rawValue ?? "Unknown"
    }
}

enum AudioError: LocalizedError {
    case playbackFailed(Error)
    case fileNotFound
    case invalidFormat
    case audioSessionError(String)
    case crossfadeFailed
    var errorDescription: String? {
        switch self {
        case .playbackFailed(let error): return "Playback failed: \(error.localizedDescription)"
        case .fileNotFound:              return "Audio file not found"
        case .invalidFormat:             return "Invalid audio format"
        case .audioSessionError(let m):  return "Audio session error: \(m)"
        case .crossfadeFailed:           return "Crossfade transition failed"
        }
    }
}

enum PlayerInstance { case primary, secondary }

enum AudioRoute {
    case builtin, headphones, bluetooth, carPlay, airPlay
    var description: String {
        switch self {
        case .builtin:   return "Built-in Speaker"
        case .headphones:return "Headphones"
        case .bluetooth: return "Bluetooth"
        case .carPlay:   return "CarPlay"
        case .airPlay:   return "AirPlay"
        }
    }
}

enum AudioConnectionStatus {
    case builtin, headphones, bluetooth, carPlay, airPlay
    var icon: String {
        switch self {
        case .builtin:   return "speaker.wave.2"
        case .headphones:return "headphones"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .carPlay:   return "car"
        case .airPlay:   return "airplay"
        }
    }
}

enum AudioSessionState: Equatable {
    case inactive, active, interrupted, error(String)
    var description: String {
        switch self {
        case .inactive:         return "Inactive"
        case .active:           return "Active"
        case .interrupted:      return "Interrupted"
        case .error(let msg):   return "Error: \(msg)"
        }
    }
}
