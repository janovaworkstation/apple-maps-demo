import Foundation
import AVFoundation
import Combine

// MARK: - AudioStorageService Protocol

@MainActor
protocol AudioStorageServiceProtocol {
    // File Management
    func getLocalURL(for audioContent: AudioContent) -> URL
    func isFileAvailable(for audioContent: AudioContent) -> Bool
    func getFileSize(for audioContent: AudioContent) -> Int64
    func deleteLocalFile(for audioContent: AudioContent) async throws
    
    // Download Management
    func downloadAudio(_ audioContent: AudioContent, priority: DownloadPriority) async throws
    func cancelDownload(for audioContent: AudioContent)
    func pauseDownload(for audioContent: AudioContent)
    func resumeDownload(for audioContent: AudioContent)
    
    // Cache Management
    func getCacheStatistics() -> CacheStatistics
    func clearCache(olderThan: TimeInterval?) async throws
    func optimizeCache() async throws
    func preloadTourAudio(tourId: UUID, strategy: PreloadStrategy) async
    
    // Publishers
    var downloadProgress: AnyPublisher<DownloadProgress, Never> { get }
    var cacheUpdates: AnyPublisher<CacheUpdate, Never> { get }
}

// MARK: - AudioStorageService Implementation

@MainActor
class AudioStorageService: AudioStorageServiceProtocol, ObservableObject {
    static let shared = AudioStorageService()
    
    // MARK: - Dependencies
    private let dataService: DataService
    private let fileManager = FileManager.default
    
    // MARK: - State
    @Published private(set) var activeDownloads: [UUID: DownloadTask] = [:]
    @Published private(set) var downloadQueue: [UUID] = []
    @Published private(set) var cacheStatistics: CacheStatistics = CacheStatistics()
    @Published private(set) var storageUsage: StorageUsage = StorageUsage()
    
    // MARK: - Publishers
    private let downloadProgressSubject = PassthroughSubject<DownloadProgress, Never>()
    private let cacheUpdatesSubject = PassthroughSubject<CacheUpdate, Never>()
    
    var downloadProgress: AnyPublisher<DownloadProgress, Never> {
        downloadProgressSubject.eraseToAnyPublisher()
    }
    
    var cacheUpdates: AnyPublisher<CacheUpdate, Never> {
        cacheUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Configuration
    private let maxConcurrentDownloads = 3
    private let maxCacheSize: Int64 = 2 * 1024 * 1024 * 1024 // 2GB default
    private let downloadSession: URLSession
    private let processingQueue = DispatchQueue(label: "audio-storage", qos: .utility)
    
    // MARK: - Storage Structure
    private var baseStorageURL: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("AudioContent")
    }
    
    private var toursDirectory: URL {
        return baseStorageURL.appendingPathComponent("Tours")
    }
    
    private var tempDirectory: URL {
        return baseStorageURL.appendingPathComponent("Temp")
    }
    
    private var cacheMetadataURL: URL {
        return baseStorageURL.appendingPathComponent("cache_metadata.json")
    }
    
    // MARK: - Initialization
    
    private init(dataService: DataService? = nil) {
        self.dataService = dataService ?? MainActor.assumeIsolated { DataService.shared }
        
        // Configure URLSession for background downloads
        let config = URLSessionConfiguration.background(withIdentifier: "com.applemapsdemo.audiodownloads")
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.downloadSession = URLSession(configuration: config)
        
        Task {
            await initializeStorageStructure()
            await loadCacheMetadata()
            await updateStorageStatistics()
        }
    }
    
    private func initializeStorageStructure() async {
        do {
            // Create directory structure
            try fileManager.createDirectory(at: baseStorageURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: toursDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            
            print("✅ Audio storage structure initialized at: \(baseStorageURL.path)")
        } catch {
            print("❌ Failed to initialize storage structure: \(error)")
        }
    }
    
    // MARK: - File Management
    
    func getLocalURL(for audioContent: AudioContent) -> URL {
        let tourDirectory = toursDirectory.appendingPathComponent(audioContent.poiId.uuidString)
        return tourDirectory.appendingPathComponent(audioContent.generateLocalFilename())
    }
    
    func isFileAvailable(for audioContent: AudioContent) -> Bool {
        let localURL = getLocalURL(for: audioContent)
        return fileManager.fileExists(atPath: localURL.path)
    }
    
    func getFileSize(for audioContent: AudioContent) -> Int64 {
        let localURL = getLocalURL(for: audioContent)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func deleteLocalFile(for audioContent: AudioContent) async throws {
        let localURL = getLocalURL(for: audioContent)
        
        guard fileManager.fileExists(atPath: localURL.path) else {
            return // File doesn't exist, nothing to delete
        }
        
        do {
            try fileManager.removeItem(at: localURL)
            
            // Update audio content status
            audioContent.localFileURL = nil
            audioContent.cachedAt = nil
            audioContent.downloadStatus = .notStarted
            audioContent.fileSize = 0
            
            // Save updated audio content
            try await dataService.audioRepository.save(audioContent)
            
            // Update cache statistics
            await updateStorageStatistics()
            
            // Notify about cache update
            cacheUpdatesSubject.send(.fileDeleted(audioContent.id))
            
            print("🗑️ Deleted audio file for POI: \(audioContent.poiId)")
        } catch {
            throw AudioStorageError.fileDeletionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Download Management
    
    func downloadAudio(_ audioContent: AudioContent, priority: DownloadPriority = .normal) async throws {
        guard let remoteURL = audioContent.remoteURL,
              let url = URL(string: remoteURL) else {
            throw AudioStorageError.invalidURL
        }
        
        // Check if already downloading
        if activeDownloads[audioContent.id] != nil {
            print("⚠️ Download already in progress for: \(audioContent.id)")
            return
        }
        
        // Check if file already exists
        if isFileAvailable(for: audioContent) && audioContent.downloadStatus == .completed {
            print("✅ File already downloaded for: \(audioContent.id)")
            return
        }
        
        // Ensure directory exists
        let localURL = getLocalURL(for: audioContent)
        try fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Create download task
        let downloadTask = DownloadTask(
            id: audioContent.id,
            remoteURL: url,
            localURL: localURL,
            audioContent: audioContent,
            priority: priority,
            session: downloadSession
        )
        
        // Add to active downloads
        activeDownloads[audioContent.id] = downloadTask
        
        // Update audio content status
        audioContent.downloadStatus = .inProgress(progress: 0.0)
        try await dataService.audioRepository.save(audioContent)
        
        // Start download
        try await downloadTask.start { [weak self] progress in
            await self?.handleDownloadProgress(audioContent.id, progress: progress)
        } completion: { [weak self] result in
            await self?.handleDownloadCompletion(audioContent.id, result: result)
        }
        
        print("📥 Started download for POI: \(audioContent.poiId)")
    }
    
    private func handleDownloadProgress(_ contentId: UUID, progress: Double) async {
        guard let downloadTask = activeDownloads[contentId] else { return }
        
        // Update audio content progress
        downloadTask.audioContent.downloadStatus = .inProgress(progress: progress)
        try? await dataService.audioRepository.save(downloadTask.audioContent)
        
        // Notify subscribers
        downloadProgressSubject.send(DownloadProgress(
            contentId: contentId,
            progress: progress,
            bytesDownloaded: Int64(progress * Double(downloadTask.audioContent.fileSize)),
            totalBytes: downloadTask.audioContent.fileSize
        ))
    }
    
    private func handleDownloadCompletion(_ contentId: UUID, result: Result<URL, Error>) async {
        guard let downloadTask = activeDownloads[contentId] else { return }
        
        // Remove from active downloads
        activeDownloads.removeValue(forKey: contentId)
        
        switch result {
        case .success(let localURL):
            // Update audio content
            downloadTask.audioContent.setLocalURL(localURL)
            downloadTask.audioContent.downloadStatus = .completed
            downloadTask.audioContent.completeDownload()
            
            // Verify file integrity
            if downloadTask.audioContent.verifyIntegrity() {
                print("✅ Download completed and verified for POI: \(downloadTask.audioContent.poiId)")
            } else {
                print("⚠️ Download completed but integrity check failed for POI: \(downloadTask.audioContent.poiId)")
            }
            
            // Save updated audio content
            try? await dataService.audioRepository.save(downloadTask.audioContent)
            
            // Update cache statistics
            await updateStorageStatistics()
            
            // Notify about successful download
            cacheUpdatesSubject.send(.downloadCompleted(contentId))
            
        case .failure(let error):
            // Update audio content with error
            downloadTask.audioContent.downloadStatus = .failed(error: error.localizedDescription)
            try? await dataService.audioRepository.save(downloadTask.audioContent)
            
            print("❌ Download failed for POI: \(downloadTask.audioContent.poiId) - \(error)")
            
            // Notify about failed download
            cacheUpdatesSubject.send(.downloadFailed(contentId, error))
        }
    }
    
    func cancelDownload(for audioContent: AudioContent) {
        guard let downloadTask = activeDownloads[audioContent.id] else { return }
        
        downloadTask.cancel()
        activeDownloads.removeValue(forKey: audioContent.id)
        
        // Update status
        audioContent.downloadStatus = .notStarted
        Task {
            try? await dataService.audioRepository.save(audioContent)
        }
        
        print("🚫 Cancelled download for POI: \(audioContent.poiId)")
    }
    
    func pauseDownload(for audioContent: AudioContent) {
        guard let downloadTask = activeDownloads[audioContent.id] else { return }
        
        downloadTask.pause()
        audioContent.downloadStatus = .paused
        
        Task {
            try? await dataService.audioRepository.save(audioContent)
        }
        
        print("⏸️ Paused download for POI: \(audioContent.poiId)")
    }
    
    func resumeDownload(for audioContent: AudioContent) {
        guard let downloadTask = activeDownloads[audioContent.id] else { return }
        
        downloadTask.resume()
        
        if case .inProgress(let progress) = audioContent.downloadStatus {
            audioContent.downloadStatus = .inProgress(progress: progress)
        } else {
            audioContent.downloadStatus = .inProgress(progress: 0.0)
        }
        
        Task {
            try? await dataService.audioRepository.save(audioContent)
        }
        
        print("▶️ Resumed download for POI: \(audioContent.poiId)")
    }
    
    // MARK: - Cache Management
    
    func getCacheStatistics() -> CacheStatistics {
        return cacheStatistics
    }
    
    private func updateStorageStatistics() async {
        let totalSize = calculateDirectorySize(at: baseStorageURL)
        let fileCount = countFilesInDirectory(at: baseStorageURL)
        
        storageUsage = StorageUsage(
            totalSize: totalSize,
            availableSpace: getAvailableSpace(),
            fileCount: fileCount,
            lastUpdated: Date()
        )
        
        cacheStatistics = CacheStatistics(
            totalFiles: fileCount,
            totalSize: totalSize,
            availableSpace: storageUsage.availableSpace,
            utilizationPercentage: Double(totalSize) / Double(maxCacheSize) * 100,
            lastCleanup: cacheStatistics.lastCleanup
        )
        
        print("📊 Cache statistics updated: \(fileCount) files, \(ByteCountFormatter().string(fromByteCount: totalSize))")
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    private func countFilesInDirectory(at url: URL) -> Int {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return 0
        }
        
        return enumerator.allObjects.count
    }
    
    private func getAvailableSpace() -> Int64 {
        do {
            let resourceValues = try baseStorageURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(resourceValues.volumeAvailableCapacity ?? 0)
        } catch {
            return 0
        }
    }
    
    func clearCache(olderThan timeInterval: TimeInterval? = nil) async throws {
        let cutoffDate = timeInterval.map { Date().addingTimeInterval(-$0) }
        var deletedFiles = 0
        var freedSpace: Int64 = 0
        
        // Get all audio content
        let allAudioContent = try await dataService.audioRepository.fetchAll()
        
        for audioContent in allAudioContent {
            // Skip if file is not cached
            guard audioContent.isAvailableOffline else { continue }
            
            // Skip if cutoff date is specified and file is newer
            if let cutoffDate = cutoffDate,
               let cachedAt = audioContent.cachedAt,
               cachedAt > cutoffDate {
                continue
            }
            
            // Delete file
            let fileSize = audioContent.fileSize
            try await deleteLocalFile(for: audioContent)
            
            deletedFiles += 1
            freedSpace += fileSize
        }
        
        await updateStorageStatistics()
        cacheStatistics.lastCleanup = Date()
        
        cacheUpdatesSubject.send(.cacheCleared(deletedFiles: deletedFiles, freedSpace: freedSpace))
        
        print("🧹 Cache cleaned: \(deletedFiles) files deleted, \(ByteCountFormatter().string(fromByteCount: freedSpace)) freed")
    }
    
    func optimizeCache() async throws {
        // Implement LRU cache optimization
        let allAudioContent = try await dataService.audioRepository.fetchAll()
        let cachedContent = allAudioContent.filter { $0.isAvailableOffline }
        
        // Sort by last played date (LRU)
        let sortedByUsage = cachedContent.sorted { (content1, content2) in
            let date1 = content1.lastPlayed ?? content1.cachedAt ?? Date.distantPast
            let date2 = content2.lastPlayed ?? content2.cachedAt ?? Date.distantPast
            return date1 < date2
        }
        
        // Calculate current cache size
        let currentCacheSize = sortedByUsage.reduce(0) { $0 + $1.fileSize }
        
        // If we're over the cache limit, remove least recently used files
        if currentCacheSize > maxCacheSize {
            var sizeToFree = currentCacheSize - maxCacheSize + (maxCacheSize / 10) // Free extra 10%
            var freedSpace: Int64 = 0
            var deletedFiles = 0
            
            for audioContent in sortedByUsage {
                guard sizeToFree > 0 else { break }
                
                let fileSize = audioContent.fileSize
                try await deleteLocalFile(for: audioContent)
                
                sizeToFree -= fileSize
                freedSpace += fileSize
                deletedFiles += 1
            }
            
            await updateStorageStatistics()
            cacheUpdatesSubject.send(.cacheOptimized(deletedFiles: deletedFiles, freedSpace: freedSpace))
            
            print("⚡ Cache optimized: \(deletedFiles) files removed, \(ByteCountFormatter().string(fromByteCount: freedSpace)) freed")
        }
    }
    
    // MARK: - Preloading
    
    func preloadTourAudio(tourId: UUID, strategy: PreloadStrategy = .priorityOnly) async {
        do {
            let pois = try await dataService.poiRepository.fetchByTour(tourId)
            
            // Fetch audio content for each POI
            var audioContentList: [AudioContent] = []
            for poi in pois {
                let poiAudioContent = try await dataService.audioRepository.fetchByPOI(poi.id)
                audioContentList.append(contentsOf: poiAudioContent)
            }
            
            let filteredContent: [AudioContent]
            
            switch strategy {
            case .all:
                filteredContent = audioContentList
            case .priorityOnly:
                // Only preload high and critical importance POIs
                filteredContent = audioContentList.filter { audioContent in
                    if let poi = pois.first(where: { $0.id == audioContent.poiId }) {
                        return poi.importance == .high || poi.importance == .critical
                    }
                    return false
                }
            case .nextThree:
                // Preload next 3 POIs in tour order
                let sortedPOIs = pois.sorted { $0.order < $1.order }
                let nextThreePOIs = Array(sortedPOIs.prefix(3))
                filteredContent = audioContentList.filter { audioContent in
                    nextThreePOIs.contains { $0.id == audioContent.poiId }
                }
            }
            
            // Start downloads for filtered content
            for audioContent in filteredContent {
                guard !audioContent.isAvailableOffline else { continue }
                
                try await downloadAudio(audioContent, priority: .high)
            }
            
            print("📥 Started preloading \(filteredContent.count) audio files for tour: \(tourId)")
            
        } catch {
            print("❌ Failed to preload tour audio: \(error)")
        }
    }
    
    // MARK: - Cache Metadata
    
    private func loadCacheMetadata() async {
        // Load cache metadata from disk if available
        guard fileManager.fileExists(atPath: cacheMetadataURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheMetadataURL)
            cacheStatistics = try JSONDecoder().decode(CacheStatistics.self, from: data)
            print("📋 Loaded cache metadata")
        } catch {
            print("⚠️ Failed to load cache metadata: \(error)")
        }
    }
    
    private func saveCacheMetadata() async {
        do {
            let data = try JSONEncoder().encode(cacheStatistics)
            try data.write(to: cacheMetadataURL)
        } catch {
            print("⚠️ Failed to save cache metadata: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct DownloadProgress {
    let contentId: UUID
    let progress: Double
    let bytesDownloaded: Int64
    let totalBytes: Int64
    
    var formattedProgress: String {
        return "\(Int(progress * 100))%"
    }
    
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        let downloaded = formatter.string(fromByteCount: bytesDownloaded)
        let total = formatter.string(fromByteCount: totalBytes)
        return "\(downloaded) / \(total)"
    }
}

enum CacheUpdate {
    case downloadCompleted(UUID)
    case downloadFailed(UUID, Error)
    case fileDeleted(UUID)
    case cacheCleared(deletedFiles: Int, freedSpace: Int64)
    case cacheOptimized(deletedFiles: Int, freedSpace: Int64)
}

enum DownloadPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

enum PreloadStrategy {
    case all
    case priorityOnly
    case nextThree
}

struct CacheStatistics: Codable {
    var totalFiles: Int
    var totalSize: Int64
    var availableSpace: Int64
    var utilizationPercentage: Double
    var lastCleanup: Date?
    
    init(
        totalFiles: Int = 0,
        totalSize: Int64 = 0,
        availableSpace: Int64 = 0,
        utilizationPercentage: Double = 0,
        lastCleanup: Date? = nil
    ) {
        self.totalFiles = totalFiles
        self.totalSize = totalSize
        self.availableSpace = availableSpace
        self.utilizationPercentage = utilizationPercentage
        self.lastCleanup = lastCleanup
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter().string(fromByteCount: totalSize)
    }
    
    var formattedAvailableSpace: String {
        ByteCountFormatter().string(fromByteCount: availableSpace)
    }
}

struct StorageUsage {
    let totalSize: Int64
    let availableSpace: Int64
    let fileCount: Int
    let lastUpdated: Date
    
    init(
        totalSize: Int64 = 0,
        availableSpace: Int64 = 0,
        fileCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.totalSize = totalSize
        self.availableSpace = availableSpace
        self.fileCount = fileCount
        self.lastUpdated = lastUpdated
    }
    
    var utilizationPercentage: Double {
        guard availableSpace > 0 else { return 0 }
        return Double(totalSize) / Double(totalSize + availableSpace) * 100
    }
}

enum AudioStorageError: LocalizedError {
    case invalidURL
    case fileDeletionFailed(String)
    case downloadFailed(String)
    case cacheOptimizationFailed(String)
    case insufficientStorage
    case fileSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .fileDeletionFailed(let details):
            return "Failed to delete file: \(details)"
        case .downloadFailed(let details):
            return "Download failed: \(details)"
        case .cacheOptimizationFailed(let details):
            return "Cache optimization failed: \(details)"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .fileSystemError(let details):
            return "File system error: \(details)"
        }
    }
}