import Foundation
import Combine
import SwiftUI

@MainActor
final class AudioQueueViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var queueItems: [AudioQueueItem] = []
    @Published var currentProgress: Double = 0
    @Published var totalQueueTime: String = "0:00"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var audioManager: AudioManager?
    private var cancellables = Set<AnyCancellable>()
    private var progressUpdateTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupProgressTimer()
        print("🎵 AudioQueueViewModel initialized")
    }
    
    deinit {
        // Clean up synchronously to avoid capture issues
        progressUpdateTimer?.invalidate()
        progressUpdateTimer = nil
        cancellables.removeAll()
        print("🧹 AudioQueueViewModel cleaned up")
    }
    
    // MARK: - Setup
    
    func setupAudioManager(_ manager: AudioManager) {
        self.audioManager = manager
        setupBindings()
        loadQueueItems()
        print("✅ AudioQueueViewModel connected to AudioManager")
    }
    
    private func setupBindings() {
        guard let audioManager = audioManager else { return }
        
        // Monitor playback progress
        audioManager.$currentTime
            .combineLatest(audioManager.$duration)
            .sink { [weak self] currentTime, duration in
                self?.updateCurrentProgress(currentTime: currentTime, duration: duration)
            }
            .store(in: &cancellables)
        
        // Monitor current POI changes
        audioManager.$currentPOI
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadQueueItems()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupProgressTimer() {
        progressUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTotalQueueTime()
            }
        }
    }
    
    // MARK: - Public Interface
    
    func playItem(_ item: AudioQueueItem) async {
        guard let audioManager = audioManager else {
            setError("Audio manager not available")
            return
        }
        
        do {
            try await audioManager.playAudio(from: item.url, for: item.poi)
            print("🎵 Playing audio for POI: \(item.poi.name)")
        } catch {
            setError("Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    func removeItem(_ item: AudioQueueItem) async {
        // For now, just remove from local queue
        if let index = queueItems.firstIndex(of: item) {
            queueItems.remove(at: index)
            updateTotalQueueTime()
            print("🗑️ Removed \(item.poi.name) from queue")
        }
    }
    
    func moveItems(from source: IndexSet, to destination: Int) async {
        // For now, just reorder the local queue
        queueItems.move(fromOffsets: source, toOffset: destination)
        updateTotalQueueTime()
        print("🔄 Reordered queue items")
    }
    
    func deleteItems(at offsets: IndexSet) async {
        let itemsToDelete = offsets.map { queueItems[$0] }
        
        for item in itemsToDelete {
            await removeItem(item)
        }
    }
    
    func clearQueue() async {
        queueItems.removeAll()
        updateTotalQueueTime()
        print("🧹 Cleared audio queue")
    }
    
    func refreshQueue() {
        loadQueueItems()
    }
    
    // MARK: - Private Methods
    
    private func loadQueueItems() {
        // For now, create mock queue items based on current tour
        // In a real implementation, this would come from AudioManager
        queueItems = []
        updateTotalQueueTime()
    }
    
    private func updateQueueItems(from queue: [AudioQueueItem]) {
        queueItems = queue
        updateTotalQueueTime()
    }
    
    private func updateCurrentProgress(currentTime: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else {
            currentProgress = 0
            return
        }
        
        currentProgress = currentTime / duration
    }
    
    private func updateTotalQueueTime() {
        let totalSeconds = queueItems.reduce(0.0) { total, item in
            total + item.estimatedDuration
        }
        
        totalQueueTime = formatDuration(totalSeconds)
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        print("❌ AudioQueueViewModel Error: \(message)")
        
        // Auto-dismiss error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.errorMessage == message {
                self?.errorMessage = nil
            }
        }
    }
    
    private func cleanup() {
        progressUpdateTimer?.invalidate()
        progressUpdateTimer = nil
        cancellables.removeAll()
        print("🧹 AudioQueueViewModel cleaned up")
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
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

// MARK: - Extended AudioQueueItem

extension AudioQueueItem: Identifiable, Equatable {
    var id: UUID {
        poi.id
    }
    
    var estimatedDuration: TimeInterval {
        // Mock duration - in real implementation would come from audio metadata
        300.0 // 5 minutes default
    }
    
    var priority: DownloadPriority {
        .normal
    }
    
    var status: QueueItemStatus {
        .ready
    }
    
    var downloadStatus: DownloadStatus {
        .completed
    }
    
    var addedAt: Date {
        Date()
    }
    
    var isPlayable: Bool {
        true
    }
    
    static func == (lhs: AudioQueueItem, rhs: AudioQueueItem) -> Bool {
        lhs.poi.id == rhs.poi.id
    }
}

// MARK: - Supporting Enums

enum QueueItemStatus: String, CaseIterable {
    case pending = "pending"
    case ready = "ready"
    case playing = "playing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .ready: return "Ready"
        case .playing: return "Playing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .ready: return .blue
        case .playing: return .green
        case .completed: return .gray
        case .failed: return .red
        }
    }
}

// Using existing DownloadStatus and DownloadPriority from other files

// MARK: - AudioManager Queue Extension
// Note: These methods would be implemented in AudioManager in a real application