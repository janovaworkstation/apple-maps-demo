import Foundation
import Combine
import AVFoundation

@MainActor
final class AudioPlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlayerReady: Bool = false
    @Published var errorMessage: String?
    @Published var showingQueue: Bool = false
    @Published var showingTranscript: Bool = false
    
    // MARK: - Private Properties
    private var audioManager: AudioManager?
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        print("🎵 AudioPlayerViewModel initialized")
    }
    
    deinit {
        // Clean up synchronously to avoid capture issues
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        print("🧹 AudioPlayerViewModel cleaned up")
    }
    
    // MARK: - Setup
    
    func setupAudioManager(_ manager: AudioManager) {
        self.audioManager = manager
        setupBindings()
        isPlayerReady = true
        print("✅ AudioPlayerViewModel connected to AudioManager")
    }
    
    private func setupBindings() {
        guard let audioManager = audioManager else { return }
        
        // Monitor playback state changes
        audioManager.$isPlaying
            .sink { [weak self] isPlaying in
                self?.handlePlaybackStateChange(isPlaying)
            }
            .store(in: &cancellables)
        
        // Note: AudioManager doesn't have errorMessage property
        // Error handling is done locally in this ViewModel
        
        // Monitor POI changes
        audioManager.$currentPOI
            .sink { [weak self] poi in
                self?.handlePOIChange(poi)
            }
            .store(in: &cancellables)
        
        // Start real-time updates
        startRealTimeUpdates()
    }
    
    private func startRealTimeUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func updateProgress() {
        // This method is called frequently to update UI in real-time
        // The actual time values are already published by AudioManager
        // This is mainly for any additional UI state that needs frequent updates
    }
    
    // MARK: - Public Interface
    
    func togglePlayback() async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.resume()
        }
    }
    
    func skipForward() async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        let newTime = min(audioManager.currentTime + 30, audioManager.duration)
        audioManager.seek(to: newTime)
    }
    
    func skipBackward() async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        let newTime = max(audioManager.currentTime - 30, 0)
        audioManager.seek(to: newTime)
    }
    
    func seekToTime(_ time: TimeInterval) async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        audioManager.seek(to: time)
    }
    
    func setPlaybackSpeed(_ speed: Float) async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        audioManager.setPlaybackRate(speed)
    }
    
    func setVolume(_ volume: Float) async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        audioManager.setVolume(volume)
    }
    
    func nextTrack() async {
        guard audioManager != nil else {
            setError("Audio manager not available")
            return
        }
        
        // Use the private method through a public interface if available
        // For now, just log that next track was requested
        print("🎵 Next track requested")
    }
    
    func previousTrack() async {
        guard audioManager != nil else {
            setError("Audio manager not available")
            return
        }
        
        // Use the private method through a public interface if available
        // For now, just log that previous track was requested
        print("🎵 Previous track requested")
    }
    
    func toggleQueue() {
        showingQueue.toggle()
    }
    
    func toggleTranscript() {
        showingTranscript.toggle()
    }
    
    func dismissError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func handlePlaybackStateChange(_ isPlaying: Bool) {
        // Additional UI state updates based on playback state
        if !isPlaying {
            // Clear any temporary UI states when playback stops
        }
    }
    
    private func handlePOIChange(_ poi: PointOfInterest?) {
        // Reset UI state when POI changes
        showingTranscript = false
        errorMessage = nil
        
        if poi != nil {
            print("🎵 AudioPlayerViewModel: New POI loaded - \(poi?.name ?? "Unknown")")
        }
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        print("❌ AudioPlayerViewModel Error: \(message)")
        
        // Auto-dismiss error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.errorMessage == message {
                self?.errorMessage = nil
            }
        }
    }
    
    private func cleanup() {
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        print("🧹 AudioPlayerViewModel cleaned up")
    }
    
    // MARK: - Computed Properties
    
    var hasCurrentPOI: Bool {
        audioManager?.currentPOI != nil
    }
    
    var isBuffering: Bool {
        audioManager?.isBuffering ?? false
    }
    
    var isCrossfading: Bool {
        audioManager?.isCrossfading ?? false
    }
    
    var canSkipForward: Bool {
        guard let audioManager = audioManager else { return false }
        return audioManager.currentTime + 30 < audioManager.duration
    }
    
    var canSkipBackward: Bool {
        guard let audioManager = audioManager else { return false }
        return audioManager.currentTime >= 30
    }
    
    var formattedCurrentTime: String {
        guard let audioManager = audioManager else { return "0:00" }
        return formatTime(audioManager.currentTime)
    }
    
    var formattedDuration: String {
        guard let audioManager = audioManager else { return "0:00" }
        return formatTime(audioManager.duration)
    }
    
    var progressPercentage: Double {
        guard let audioManager = audioManager, audioManager.duration > 0 else { return 0 }
        return audioManager.currentTime / audioManager.duration
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Error Extension

extension AudioPlayerViewModel {
    enum AudioPlayerError: LocalizedError {
        case managerNotAvailable
        case playbackFailed(String)
        case seekFailed(String)
        case speedChangeFailed(String)
        case volumeChangeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .managerNotAvailable:
                return "Audio manager is not available"
            case .playbackFailed(let message):
                return "Playback failed: \(message)"
            case .seekFailed(let message):
                return "Seek operation failed: \(message)"
            case .speedChangeFailed(let message):
                return "Speed change failed: \(message)"
            case .volumeChangeFailed(let message):
                return "Volume change failed: \(message)"
            }
        }
    }
}