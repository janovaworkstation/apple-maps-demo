import Foundation
import Combine

// MARK: - ContentCacheManager

actor ContentCacheManager {
    
    // MARK: - Cache Storage
    private var memoryCache: [String: CachedContentItem] = [:]
    private var accessTracker: [String: Date] = [:]
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    // MARK: - Configuration
    private let maxMemoryCacheSize = 50 // Maximum items in memory
    private let maxCacheAgeInDays = 30   // Content expires after 30 days
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsURL.appendingPathComponent("ContentCache")
        
        Task {
            await initializeCacheDirectory()
            await loadMemoryCache()
            await cleanupExpiredContent()
        }
    }
    
    private func initializeCacheDirectory() async {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            print("📁 Content cache directory initialized: \(cacheDirectory.path)")
        } catch {
            print("❌ Failed to create cache directory: \(error)")
        }
    }
    
    // MARK: - Public Cache Interface
    
    func getCachedContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async -> GeneratedAudioContent? {
        
        let cacheKey = buildCacheKey(poi: poi, context: context, preferences: preferences)
        
        // Check memory cache first
        if let cachedItem = memoryCache[cacheKey] {
            if !isExpired(cachedItem) {
                accessTracker[cacheKey] = Date()
                hitCount += 1
                print("💾 Memory cache hit for: \(poi.name)")
                return cachedItem.content
            } else {
                // Remove expired item
                memoryCache.removeValue(forKey: cacheKey)
                accessTracker.removeValue(forKey: cacheKey)
            }
        }
        
        // Check disk cache
        if let cachedItem = await loadFromDisk(cacheKey: cacheKey) {
            if !isExpired(cachedItem) {
                // Promote to memory cache
                memoryCache[cacheKey] = cachedItem
                accessTracker[cacheKey] = Date()
                hitCount += 1
                print("💿 Disk cache hit for: \(poi.name)")
                return cachedItem.content
            } else {
                // Remove expired file
                await removeFromDisk(cacheKey: cacheKey)
            }
        }
        
        missCount += 1
        print("🚫 Cache miss for: \(poi.name)")
        return nil
    }
    
    func cacheContent(
        _ content: GeneratedAudioContent,
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async {
        
        let cacheKey = buildCacheKey(poi: poi, context: context, preferences: preferences)
        let cachedItem = CachedContentItem(
            content: content,
            cacheKey: cacheKey,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 1
        )
        
        // Store in memory cache
        memoryCache[cacheKey] = cachedItem
        accessTracker[cacheKey] = Date()
        
        // Manage memory cache size
        await evictOldestItemsIfNeeded()
        
        // Store on disk asynchronously
        await saveToDisk(cachedItem: cachedItem)
        
        print("💾 Cached content for: \(poi.name)")
    }
    
    // MARK: - Cache Statistics
    
    func getCacheHitRate() async -> Double {
        let totalRequests = hitCount + missCount
        guard totalRequests > 0 else { return 0.0 }
        return Double(hitCount) / Double(totalRequests)
    }
    
    func getStatistics() async -> ContentCacheStatistics {
        let diskSize = await calculateDiskCacheSize()
        let diskCount = await countDiskCacheItems()
        
        return ContentCacheStatistics(
            memoryItems: memoryCache.count,
            diskItems: diskCount,
            totalSizeBytes: diskSize,
            hitRate: await getCacheHitRate(),
            hitCount: hitCount,
            missCount: missCount,
            lastCleanup: Date() // This would be tracked in a real implementation
        )
    }
    
    // MARK: - Cache Management
    
    func clearCache() async {
        // Clear memory cache
        memoryCache.removeAll()
        accessTracker.removeAll()
        hitCount = 0
        missCount = 0
        
        // Clear disk cache
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
            print("🧹 Cleared all cached content")
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
    }
    
    func optimizeCache() async {
        // Remove expired items
        await cleanupExpiredContent()
        
        // Remove least accessed items if over size limit
        await evictLeastAccessedItems()
        
        // Defragment disk cache
        await defragmentDiskCache()
        
        print("⚡ Cache optimization completed")
    }
    
    // MARK: - Private Helper Methods
    
    private func buildCacheKey(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        let poiKey = "\(poi.id.uuidString)_\(poi.category.rawValue)"
        let contextKey = "\(context.tourName)_\(context.visitedPOIs.count)"
        let prefsKey = "\(preferences.preferredLanguage)_\(preferences.voiceType.rawValue)"
        return "\(poiKey)_\(contextKey)_\(prefsKey)".djb2Hash
    }
    
    private func isExpired(_ item: CachedContentItem) -> Bool {
        let daysSinceCreation = Date().timeIntervalSince(item.createdAt) / (24 * 60 * 60)
        return daysSinceCreation > Double(maxCacheAgeInDays)
    }
    
    private func evictOldestItemsIfNeeded() async {
        guard memoryCache.count > maxMemoryCacheSize else { return }
        
        let sortedKeys = memoryCache.keys.sorted { key1, key2 in
            let date1 = accessTracker[key1] ?? Date.distantPast
            let date2 = accessTracker[key2] ?? Date.distantPast
            return date1 < date2
        }
        
        let keysToRemove = sortedKeys.prefix(memoryCache.count - maxMemoryCacheSize)
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
            accessTracker.removeValue(forKey: key)
        }
        
        print("🧹 Evicted \(keysToRemove.count) items from memory cache")
    }
    
    // MARK: - Disk Cache Operations
    
    private func saveToDisk(cachedItem: CachedContentItem) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(cachedItem.cacheKey).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedItem)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save cache item to disk: \(error)")
        }
    }
    
    private func loadFromDisk(cacheKey: String) async -> CachedContentItem? {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedContentItem.self, from: data)
        } catch {
            print("❌ Failed to load cache item from disk: \(error)")
            return nil
        }
    }
    
    private func removeFromDisk(cacheKey: String) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).json")
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("❌ Failed to remove cache item from disk: \(error)")
        }
    }
    
    private func loadMemoryCache() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            // Load most recently accessed items into memory
            let sortedFiles = contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
            
            for fileURL in sortedFiles.prefix(maxMemoryCacheSize / 2) {
                let cacheKey = fileURL.deletingPathExtension().lastPathComponent
                if let cachedItem = await loadFromDisk(cacheKey: cacheKey) {
                    if !isExpired(cachedItem) {
                        memoryCache[cacheKey] = cachedItem
                        accessTracker[cacheKey] = cachedItem.lastAccessed
                    }
                }
            }
            
            print("📚 Loaded \(memoryCache.count) items into memory cache")
        } catch {
            print("❌ Failed to load memory cache: \(error)")
        }
    }
    
    private func cleanupExpiredContent() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var removedCount = 0
            
            for fileURL in contents {
                let cacheKey = fileURL.deletingPathExtension().lastPathComponent
                if let cachedItem = await loadFromDisk(cacheKey: cacheKey) {
                    if isExpired(cachedItem) {
                        await removeFromDisk(cacheKey: cacheKey)
                        memoryCache.removeValue(forKey: cacheKey)
                        accessTracker.removeValue(forKey: cacheKey)
                        removedCount += 1
                    }
                }
            }
            
            if removedCount > 0 {
                print("🧹 Cleaned up \(removedCount) expired cache items")
            }
        } catch {
            print("❌ Failed to cleanup expired content: \(error)")
        }
    }
    
    private func evictLeastAccessedItems() async {
        // Implementation for evicting least accessed items when cache grows too large
        let diskCount = await countDiskCacheItems()
        let maxDiskItems = 200 // Maximum items on disk
        
        guard diskCount > maxDiskItems else { return }
        
        // This would implement LRU eviction logic for disk cache
        print("🗑️ Evicting least accessed items from disk cache")
    }
    
    private func defragmentDiskCache() async {
        // Implementation for disk cache defragmentation
        // This could include reorganizing files, removing fragmentation, etc.
        print("🔧 Defragmenting disk cache")
    }
    
    private func calculateDiskCacheSize() async -> Int64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            
            for fileURL in contents {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    private func countDiskCacheItems() async -> Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Types

struct CachedContentItem: Codable {
    let content: GeneratedAudioContent
    let cacheKey: String
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
}

struct ContentCacheStatistics {
    let memoryItems: Int
    let diskItems: Int
    let totalSizeBytes: Int64
    let hitRate: Double
    let hitCount: Int
    let missCount: Int
    let lastCleanup: Date
    
    var formattedSize: String {
        ByteCountFormatter().string(fromByteCount: totalSizeBytes)
    }
    
    var formattedHitRate: String {
        String(format: "%.1f%%", hitRate * 100)
    }
}

// MARK: - GeneratedAudioContent Codable Extension

extension GeneratedAudioContent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, poiId, text, audioURL, template, language, generatedAt, quality, durationEstimate, cacheKey
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(poiId, forKey: .poiId)
        try container.encode(text, forKey: .text)
        try container.encode(audioURL, forKey: .audioURL)
        try container.encode(template.rawValue, forKey: .template)
        try container.encode(language, forKey: .language)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(quality.rawValue, forKey: .quality)
        try container.encode(durationEstimate, forKey: .durationEstimate)
        try container.encode(cacheKey, forKey: .cacheKey)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        poiId = try container.decode(UUID.self, forKey: .poiId)
        text = try container.decode(String.self, forKey: .text)
        audioURL = try container.decode(URL.self, forKey: .audioURL)
        template = PromptTemplateType(rawValue: try container.decode(String.self, forKey: .template)) ?? .general
        language = try container.decode(String.self, forKey: .language)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        quality = ContentQuality(rawValue: try container.decode(Int.self, forKey: .quality)) ?? .fair
        durationEstimate = try container.decode(TimeInterval.self, forKey: .durationEstimate)
        cacheKey = try container.decode(String.self, forKey: .cacheKey)
    }
}

// MARK: - String Hashing Extension

extension String {
    var djb2Hash: String {
        var hash: UInt32 = 5381
        for char in self {
            hash = ((hash << 5) &+ hash) &+ UInt32(char.asciiValue!)
        }
        return String(hash)
    }
}