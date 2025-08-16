import Foundation
import SwiftData
import AVFoundation

// MARK: - AudioContent Repository Protocol

protocol AudioContentRepositoryProtocol {
    // Basic CRUD
    func save(_ audioContent: AudioContent) async throws
    func fetchAll() async throws -> [AudioContent]
    func fetch(by id: UUID) async throws -> AudioContent?
    func fetchByPOI(_ poiId: UUID) async throws -> [AudioContent]
    func delete(_ audioContent: AudioContent) async throws
    
    // Download Management
    func fetchDownloadedContent() async throws -> [AudioContent]
    func fetchPendingDownloads() async throws -> [AudioContent]
    func fetchFailedDownloads() async throws -> [AudioContent]
    func updateDownloadStatus(_ audioContent: AudioContent, status: DownloadStatus) async throws
    func updateDownloadProgress(_ audioContent: AudioContent, progress: Double) async throws
    
    // Cache Management
    func fetchCachedContent() async throws -> [AudioContent]
    func fetchExpiredCache(olderThan date: Date) async throws -> [AudioContent]
    func clearExpiredCache() async throws
    func getCacheSize() async throws -> Int64
    func clearAllCache() async throws
    
    // Content Type Filtering
    func fetchLLMGeneratedContent() async throws -> [AudioContent]
    func fetchPreRecordedContent() async throws -> [AudioContent]
    func fetchContentByLanguage(_ language: String) async throws -> [AudioContent]
    func fetchContentByQuality(_ quality: AudioQuality) async throws -> [AudioContent]
    
    // File Management
    func updateLocalFileURL(_ audioContent: AudioContent, url: URL?) async throws
    func verifyFileIntegrity(_ audioContent: AudioContent) async throws -> Bool
    func repairCorruptedFile(_ audioContent: AudioContent) async throws
    
    // Analytics and Statistics
    func getStorageStatistics() async throws -> AudioStorageStatistics
    func getDownloadStatistics() async throws -> AudioDownloadStatistics
    func getPlaybackHistory(for audioContent: AudioContent) async throws -> [PlaybackSession]
    
    // Queue Management
    func getDownloadQueue() async throws -> [AudioContent]
    func addToDownloadQueue(_ audioContent: AudioContent, priority: DownloadPriority) async throws
    func removeFromDownloadQueue(_ audioContent: AudioContent) async throws
    func reorderDownloadQueue(newOrder: [(UUID, Int)]) async throws
}

// MARK: - AudioContent Repository Implementation

class AudioContentRepository: AudioContentRepositoryProtocol {
    private let dataManager: DataManager
    private let fileManager = FileManager.default
    
    init(dataManager: DataManager = DataManager.shared) {
        self.dataManager = dataManager
    }
    
    // MARK: - Basic CRUD
    
    func save(_ audioContent: AudioContent) async throws {
        try await dataManager.save(audioContent)
    }
    
    func fetchAll() async throws -> [AudioContent] {
        return try await dataManager.fetch(AudioContent.self)
    }
    
    func fetch(by id: UUID) async throws -> AudioContent? {
        let predicate = #Predicate<AudioContent> { content in
            content.id == id
        }
        return try await dataManager.fetchFirst(AudioContent.self, predicate: predicate)
    }
    
    func fetchByPOI(_ poiId: UUID) async throws -> [AudioContent] {
        let predicate = #Predicate<AudioContent> { content in
            content.poiId == poiId
        }
        return try await dataManager.fetch(AudioContent.self, predicate: predicate)
    }
    
    func delete(_ audioContent: AudioContent) async throws {
        // Clean up local file if it exists
        if let localURLPath = audioContent.localFileURL {
            try? fileManager.removeItem(atPath: localURLPath)
        }
        
        try await dataManager.delete(audioContent)
    }
    
    // MARK: - Download Management
    
    func fetchDownloadedContent() async throws -> [AudioContent] {
        // SwiftData predicates don't handle enum cases well, so fetch all and filter in memory
        let allContent = try await dataManager.fetch(AudioContent.self)
        return allContent.filter { content in
            if case .completed = content.downloadStatus {
                return true
            }
            return false
        }
    }
    
    func fetchPendingDownloads() async throws -> [AudioContent] {
        // SwiftData predicates don't handle enum cases well, so fetch all and filter in memory
        let allContent = try await dataManager.fetch(AudioContent.self)
        return allContent.filter { content in
            switch content.downloadStatus {
            case .notStarted, .paused, .inProgress:
                return true
            default:
                return false
            }
        }
    }
    
    func fetchFailedDownloads() async throws -> [AudioContent] {
        // SwiftData predicates don't handle enum cases well, so fetch all and filter in memory
        let allContent = try await dataManager.fetch(AudioContent.self)
        return allContent.filter { content in
            if case .failed = content.downloadStatus {
                return true
            }
            return false
        }
    }
    
    func updateDownloadStatus(_ audioContent: AudioContent, status: DownloadStatus) async throws {
        audioContent.downloadStatus = status
        
        // Update cached date when download completes
        if case .completed = status {
            audioContent.cachedAt = Date()
        }
        
        try await dataManager.save(audioContent)
    }
    
    func updateDownloadProgress(_ audioContent: AudioContent, progress: Double) async throws {
        audioContent.downloadStatus = .inProgress(progress: progress)
        try await dataManager.save(audioContent)
    }
    
    // MARK: - Cache Management
    
    func fetchCachedContent() async throws -> [AudioContent] {
        let allContent = try await dataManager.fetch(AudioContent.self)
        return allContent.filter { content in
            content.cachedAt != nil && content.localFileURL != nil
        }
    }
    
    func fetchExpiredCache(olderThan date: Date) async throws -> [AudioContent] {
        let cachedContent = try await fetchCachedContent()
        return cachedContent.filter { content in
            guard let cachedAt = content.cachedAt else { return false }
            return cachedAt < date
        }
    }
    
    func clearExpiredCache() async throws {
        let expiredContent = try await fetchExpiredCache(olderThan: Date().addingTimeInterval(-7 * 24 * 60 * 60)) // 7 days old
        
        for content in expiredContent {
            if let localURLPath = content.localFileURL {
                try? fileManager.removeItem(atPath: localURLPath)
                content.localFileURL = nil
                content.cachedAt = nil
                content.downloadStatus = .notStarted
                try await save(content)
            }
        }
    }
    
    func getCacheSize() async throws -> Int64 {
        let cachedContent = try await fetchCachedContent()
        var totalSize: Int64 = 0
        
        for content in cachedContent {
            guard let localURLPath = content.localFileURL else { continue }
            
            do {
                let attributes = try fileManager.attributesOfItem(atPath: localURLPath)
                if let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                    totalSize += fileSize
                }
            } catch {
                // File might not exist, continue
            }
        }
        
        return totalSize
    }
    
    func clearAllCache() async throws {
        let cachedContent = try await fetchCachedContent()
        
        for content in cachedContent {
            if let localURLPath = content.localFileURL {
                try? fileManager.removeItem(atPath: localURLPath)
                content.localFileURL = nil
                content.cachedAt = nil
                content.downloadStatus = .notStarted
                try await save(content)
            }
        }
    }
    
    // MARK: - Content Type Filtering
    
    func fetchLLMGeneratedContent() async throws -> [AudioContent] {
        let predicate = #Predicate<AudioContent> { content in
            content.isLLMGenerated == true
        }
        return try await dataManager.fetch(AudioContent.self, predicate: predicate)
    }
    
    func fetchPreRecordedContent() async throws -> [AudioContent] {
        let predicate = #Predicate<AudioContent> { content in
            content.isLLMGenerated == false
        }
        return try await dataManager.fetch(AudioContent.self, predicate: predicate)
    }
    
    func fetchContentByLanguage(_ language: String) async throws -> [AudioContent] {
        let predicate = #Predicate<AudioContent> { content in
            content.language == language
        }
        return try await dataManager.fetch(AudioContent.self, predicate: predicate)
    }
    
    func fetchContentByQuality(_ quality: AudioQuality) async throws -> [AudioContent] {
        let predicate = #Predicate<AudioContent> { content in
            content.quality == quality
        }
        return try await dataManager.fetch(AudioContent.self, predicate: predicate)
    }
    
    // MARK: - File Management
    
    func updateLocalFileURL(_ audioContent: AudioContent, url: URL?) async throws {
        audioContent.localFileURL = url?.path
        if url != nil {
            audioContent.cachedAt = Date()
        }
        try await dataManager.save(audioContent)
    }
    
    func verifyFileIntegrity(_ audioContent: AudioContent) async throws -> Bool {
        guard let localURLPath = audioContent.localFileURL else { return false }
        
        // Check if file exists
        guard fileManager.fileExists(atPath: localURLPath) else { return false }
        
        // Verify file size matches expected
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localURLPath)
            let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
            
            // Basic size check - file should not be empty
            if fileSize == 0 { return false }
            
            // Try to create audio player to verify format
            let localURL = URL(fileURLWithPath: localURLPath)
            let audioPlayer = try AVAudioPlayer(contentsOf: localURL)
            return audioPlayer.duration > 0
        } catch {
            return false
        }
    }
    
    func repairCorruptedFile(_ audioContent: AudioContent) async throws {
        // Mark for re-download
        audioContent.downloadStatus = .notStarted
        audioContent.localFileURL = nil
        audioContent.cachedAt = nil
        try await save(audioContent)
    }
    
    // MARK: - Analytics and Statistics
    
    func getStorageStatistics() async throws -> AudioStorageStatistics {
        let allContent = try await fetchAll()
        let downloadedContent = try await fetchDownloadedContent()
        let cacheSize = try await getCacheSize()
        
        let contentByQuality = Dictionary(grouping: allContent) { $0.quality }
        let contentByLanguage = Dictionary(grouping: allContent) { $0.language }
        
        let llmGeneratedCount = allContent.filter { $0.isLLMGenerated }.count
        let preRecordedCount = allContent.filter { !$0.isLLMGenerated }.count
        
        return AudioStorageStatistics(
            totalContent: allContent.count,
            downloadedContent: downloadedContent.count,
            totalCacheSize: cacheSize,
            contentByQuality: contentByQuality.mapValues { $0.count },
            contentByLanguage: contentByLanguage.mapValues { $0.count },
            llmGeneratedCount: llmGeneratedCount,
            preRecordedCount: preRecordedCount
        )
    }
    
    func getDownloadStatistics() async throws -> AudioDownloadStatistics {
        let pendingDownloads = try await fetchPendingDownloads()
        let failedDownloads = try await fetchFailedDownloads()
        let completedDownloads = try await fetchDownloadedContent()
        
        let inProgressDownloads = pendingDownloads.filter { content in
            if case .inProgress = content.downloadStatus { return true }
            return false
        }
        
        return AudioDownloadStatistics(
            totalDownloads: pendingDownloads.count + failedDownloads.count + completedDownloads.count,
            completedDownloads: completedDownloads.count,
            pendingDownloads: pendingDownloads.count,
            failedDownloads: failedDownloads.count,
            inProgressDownloads: inProgressDownloads.count
        )
    }
    
    func getPlaybackHistory(for audioContent: AudioContent) async throws -> [PlaybackSession] {
        // This would typically come from a separate analytics table
        // For now, return empty array - implement when adding analytics
        return []
    }
    
    // MARK: - Queue Management
    
    func getDownloadQueue() async throws -> [AudioContent] {
        let pendingDownloads = try await fetchPendingDownloads()
        
        // Sort by priority (high importance POIs first, then by order)
        return pendingDownloads.sorted { content1, content2 in
            // This would require additional priority field in AudioContent
            // For now, sort by creation date
            return content1.createdAt < content2.createdAt
        }
    }
    
    func addToDownloadQueue(_ audioContent: AudioContent, priority: DownloadPriority = .normal) async throws {
        if audioContent.downloadStatus == .notStarted {
            // Set priority metadata if needed
            try await save(audioContent)
        }
    }
    
    func removeFromDownloadQueue(_ audioContent: AudioContent) async throws {
        if case .inProgress = audioContent.downloadStatus {
            audioContent.downloadStatus = .paused
        } else {
            audioContent.downloadStatus = .notStarted
        }
        try await save(audioContent)
    }
    
    func reorderDownloadQueue(newOrder: [(UUID, Int)]) async throws {
        // Implement queue reordering logic
        // This would require a priority or order field in AudioContent
        for (contentId, _) in newOrder {
            if let content = try await fetch(by: contentId) {
                // Update priority field when added to model
                try await save(content)
            }
        }
    }
    
    // MARK: - Advanced Operations
    
    func cleanupOrphanedFiles() async throws {
        let allContent = try await fetchAll()
        let validURLs = Set(allContent.compactMap { $0.localFileURL })
        
        // Get audio storage directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioPath = documentsPath.appendingPathComponent("AudioFiles")
        
        guard fileManager.fileExists(atPath: audioPath.path) else { return }
        
        let files = try fileManager.contentsOfDirectory(atPath: audioPath.path)
        
        for file in files {
            let filePath = audioPath.appendingPathComponent(file).path
            if !validURLs.contains(filePath) {
                try? fileManager.removeItem(atPath: filePath)
            }
        }
    }
    
    func getContentForOfflineMode(tourId: UUID) async throws -> [AudioContent] {
        // SwiftData predicates don't handle enum cases well, so fetch all and filter in memory
        let allContent = try await dataManager.fetch(AudioContent.self)
        let downloadedContent = allContent.filter { content in
            if case .completed = content.downloadStatus, content.localFileURL != nil {
                return true
            }
            return false
        }
        
        // Filter by tour if needed (requires POI relationship)
        return downloadedContent
    }
    
    func prefetchContentForTour(_ tourId: UUID) async throws {
        // Get all POIs for the tour and queue their audio content for download
        // This would require POI repository integration
    }
    
    func updateMetadata(_ audioContent: AudioContent, newMetadata: AudioMetadata) async throws {
        audioContent.metadata = newMetadata
        try await save(audioContent)
    }
}

// MARK: - Supporting Types

struct AudioStorageStatistics {
    let totalContent: Int
    let downloadedContent: Int
    let totalCacheSize: Int64
    let contentByQuality: [AudioQuality: Int]
    let contentByLanguage: [String: Int]
    let llmGeneratedCount: Int
    let preRecordedCount: Int
    
    var downloadPercentage: Double {
        return totalContent > 0 ? Double(downloadedContent) / Double(totalContent) * 100.0 : 0.0
    }
    
    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalCacheSize)
    }
}

struct AudioDownloadStatistics {
    let totalDownloads: Int
    let completedDownloads: Int
    let pendingDownloads: Int
    let failedDownloads: Int
    let inProgressDownloads: Int
    
    var successRate: Double {
        let attempted = completedDownloads + failedDownloads
        return attempted > 0 ? Double(completedDownloads) / Double(attempted) * 100.0 : 0.0
    }
}

struct PlaybackSession {
    let id: UUID
    let audioContentId: UUID
    let startedAt: Date
    let duration: TimeInterval
    let completionPercentage: Double
    let wasInterrupted: Bool
    
    init(id: UUID = UUID(), audioContentId: UUID, startedAt: Date, duration: TimeInterval, completionPercentage: Double, wasInterrupted: Bool) {
        self.id = id
        self.audioContentId = audioContentId
        self.startedAt = startedAt
        self.duration = duration
        self.completionPercentage = completionPercentage
        self.wasInterrupted = wasInterrupted
    }
}

// AudioMetadata is now defined in AudioContent.swift