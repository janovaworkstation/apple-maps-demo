import Foundation
import Combine
import CoreLocation

// MARK: - HybridContentManager

@MainActor
class HybridContentManager: ObservableObject {
    static let shared = HybridContentManager()
    
    // MARK: - Dependencies
    private let connectivityManager: ConnectivityManager
    private let contentGenerator: ContentGenerator
    private let cacheManager: ContentCacheManager
    private let audioStorageService: AudioStorageService
    private let dataService: DataService
    
    // MARK: - Published Properties
    @Published var currentContentSource: ContentSource = .live
    @Published var isPreloading: Bool = false
    @Published var preloadProgress: Double = 0.0
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var preloadingTasks: [UUID: Task<Void, Never>] = [:]
    private var syncQueue: [SyncItem] = []
    private var userPreferences: UserPreferences?
    
    // Preloading strategies
    private var routeBasedPreloader: RouteBasedPreloader?
    private var predictivePreloader: PredictivePreloader?
    
    // MARK: - Initialization
    
    private init() {
        self.connectivityManager = ConnectivityManager.shared
        self.contentGenerator = ContentGenerator.shared
        self.cacheManager = ContentCacheManager()
        self.audioStorageService = AudioStorageService.shared
        self.dataService = DataService.shared
        
        setupConnectivityObserving()
        setupPreloaders()
        print("🔄 HybridContentManager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Get content for a POI using hybrid strategy: Live LLM > Cached LLM > Local
    func getContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences,
        strategy: ContentSelectionStrategy = .automatic
    ) async throws -> GeneratedAudioContent {
        
        self.userPreferences = preferences
        
        print("🔄 Getting content for POI: \(poi.name) using \(strategy)")
        
        // Respect user offline mode preference
        if preferences.offlineMode {
            return try await getOfflineContent(for: poi, context: context, preferences: preferences)
        }
        
        // Use strategy-based selection
        switch strategy {
        case .automatic:
            return try await getContentWithAutomaticStrategy(for: poi, context: context, preferences: preferences)
        case .forceLive:
            return try await getLiveContent(for: poi, context: context, preferences: preferences)
        case .forceCached:
            return try await getCachedContent(for: poi, context: context, preferences: preferences)
        case .forceLocal:
            return try await getLocalContent(for: poi, context: context, preferences: preferences)
        }
    }
    
    /// Preload content for upcoming POIs
    func preloadContent(
        for pois: [PointOfInterest],
        context: TourContext,
        preferences: UserPreferences,
        strategy: PreloadingStrategy = .priority
    ) async {
        
        guard !isPreloading else {
            print("🔄 Preloading already in progress, skipping")
            return
        }
        
        isPreloading = true
        preloadProgress = 0.0
        
        print("🎯 Starting preload for \(pois.count) POIs with strategy: \(strategy)")
        
        let prioritizedPOIs = prioritizePOIsForPreloading(pois, strategy: strategy, preferences: preferences)
        
        var completed = 0
        let total = prioritizedPOIs.count
        
        for poi in prioritizedPOIs {
            let task = Task {
                await preloadSinglePOI(poi, context: context, preferences: preferences)
                completed += 1
                preloadProgress = Double(completed) / Double(total)
            }
            
            preloadingTasks[poi.id] = task
            await task.value
        }
        
        isPreloading = false
        preloadingTasks.removeAll()
        print("✅ Preloading completed for \(completed) POIs")
    }
    
    /// Cancel all preloading tasks
    func cancelPreloading() {
        for (_, task) in preloadingTasks {
            task.cancel()
        }
        preloadingTasks.removeAll()
        isPreloading = false
        preloadProgress = 0.0
        print("🛑 Preloading cancelled")
    }
    
    /// Sync offline content when connectivity returns
    func syncWhenOnline() async {
        guard connectivityManager.isOnline else {
            print("📡 Cannot sync - offline")
            return
        }
        
        syncStatus = .syncing
        
        await syncOfflineToOnlineContent()
        await syncCacheWithLatestContent()
        syncStatus = .completed
        print("✅ Sync completed successfully")
    }
    
    // MARK: - Content Retrieval Strategies
    
    private func getContentWithAutomaticStrategy(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedAudioContent {
        
        // Priority 1: Live LLM (if network is suitable)
        if connectivityManager.isNetworkSuitableForLLM() {
            do {
                let content = try await getLiveContent(for: poi, context: context, preferences: preferences)
                currentContentSource = .live
                print("✅ Using Live LLM content for \(poi.name)")
                return content
            } catch {
                print("⚠️ Live LLM failed, falling back: \(error)")
            }
        }
        
        // Priority 2: Cached LLM content
        if let cachedContent = await getCachedContentIfAvailable(for: poi, context: context, preferences: preferences) {
            currentContentSource = .cached
            print("✅ Using Cached LLM content for \(poi.name)")
            return cachedContent
        }
        
        // Priority 3: Local content (last resort)
        currentContentSource = .local
        print("✅ Using Local content for \(poi.name)")
        return try await getLocalContent(for: poi, context: context, preferences: preferences)
    }
    
    private func getLiveContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedAudioContent {
        
        guard connectivityManager.isOnline else {
            throw HybridContentError.networkUnavailable
        }
        
        let content = try await contentGenerator.generateContent(
            for: poi,
            context: context,
            preferences: preferences
        )
        
        // Cache the newly generated content
        await cacheManager.cacheContent(content, for: poi, context: context, preferences: preferences)
        
        return content
    }
    
    private func getCachedContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedAudioContent {
        
        if let cachedContent = await cacheManager.getCachedContent(for: poi, context: context, preferences: preferences) {
            return cachedContent
        }
        
        throw HybridContentError.cachedContentNotAvailable
    }
    
    private func getCachedContentIfAvailable(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async -> GeneratedAudioContent? {
        
        return await cacheManager.getCachedContent(for: poi, context: context, preferences: preferences)
    }
    
    private func getLocalContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedAudioContent {
        
        // Check if local audio file exists
        let audioContent = try await getOrCreateAudioContent(for: poi)
        
        if audioStorageService.isFileAvailable(for: audioContent) {
            let localURL = audioStorageService.getLocalURL(for: audioContent)
            
            return GeneratedAudioContent(
                id: UUID(),
                poiId: poi.id,
                text: poi.poiDescription,
                audioURL: localURL,
                template: .general,
                language: preferences.preferredLanguage,
                generatedAt: Date(),
                quality: .fair, // Local content is typically fair quality
                durationEstimate: audioContent.duration,
                cacheKey: "local_\(poi.id)"
            )
        }
        
        throw HybridContentError.localContentNotAvailable
    }
    
    private func getOfflineContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedAudioContent {
        
        // In offline mode, try cached first, then local
        if let cachedContent = await getCachedContentIfAvailable(for: poi, context: context, preferences: preferences) {
            currentContentSource = .cached
            return cachedContent
        }
        
        currentContentSource = .local
        return try await getLocalContent(for: poi, context: context, preferences: preferences)
    }
    
    // MARK: - Preloading Logic
    
    private func prioritizePOIsForPreloading(
        _ pois: [PointOfInterest],
        strategy: PreloadingStrategy,
        preferences: UserPreferences
    ) -> [PointOfInterest] {
        
        switch strategy {
        case .priority:
            return pois.sorted { $0.importance.priority > $1.importance.priority }
            
        case .routeBased:
            return pois.sorted { $0.order < $1.order }
            
        case .predictive:
            return predictivePreloader?.prioritizePOIs(pois, preferences: preferences) ?? pois
            
        case .distance(let userLocation):
            return pois.sorted { poi1, poi2 in
                let distance1 = poi1.location.distance(from: userLocation)
                let distance2 = poi2.location.distance(from: userLocation)
                return distance1 < distance2
            }
        }
    }
    
    private func preloadSinglePOI(
        _ poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async {
        
        // Check if already cached
        if await cacheManager.getCachedContent(for: poi, context: context, preferences: preferences) != nil {
            print("📋 POI \(poi.name) already cached, skipping preload")
            return
        }
        
        // Decide what to preload based on connectivity
        if connectivityManager.isNetworkSuitableForLLM() {
            await preloadLiveLLMContent(for: poi, context: context, preferences: preferences)
        } else if connectivityManager.isNetworkSuitableForDownload() {
            await preloadLocalAudioContent(for: poi)
        }
    }
    
    private func preloadLiveLLMContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async {
        
        do {
            let content = try await contentGenerator.generateContent(
                for: poi,
                context: context,
                preferences: preferences
            )
            
            await cacheManager.cacheContent(content, for: poi, context: context, preferences: preferences)
            print("🎯 Preloaded LLM content for \(poi.name)")
        } catch {
            print("❌ Failed to preload LLM content for \(poi.name): \(error)")
        }
    }
    
    private func preloadLocalAudioContent(for poi: PointOfInterest) async {
        do {
            let audioContent = try await getOrCreateAudioContent(for: poi)
            
            if !audioStorageService.isFileAvailable(for: audioContent),
               let _ = audioContent.remoteURL {
                
                try await audioStorageService.downloadAudio(audioContent, priority: .normal)
                print("🎯 Preloaded local audio for \(poi.name)")
            }
        } catch {
            print("❌ Failed to preload local audio for \(poi.name): \(error)")
        }
    }
    
    // MARK: - Sync Operations
    
    private func syncOfflineToOnlineContent() async {
        // Sync any content that was created/modified while offline
        // This could include user preferences, bookmarks, etc.
        print("🔄 Syncing offline changes to online storage")
    }
    
    private func syncCacheWithLatestContent() async {
        guard connectivityManager.isNetworkSuitableForLLM(),
              let _ = userPreferences else { return }
        
        print("🔄 Syncing cache with latest content")
        
        // Update cached content with fresh versions if network allows
        let cacheStats = await cacheManager.getStatistics()
        print("📊 Cache has \(cacheStats.memoryItems) items to potentially refresh")
    }
    
    // MARK: - Setup Methods
    
    private func setupConnectivityObserving() {
        // Clear any existing subscriptions first
        cancellables.removeAll()
        
        // Observe connectivity changes
        NotificationCenter.default.publisher(for: Notification.Name(Constants.Notifications.connectivityChanged))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let connectivityInfo = notification.object as? ConnectivityInfo else { return }
                Task { @MainActor in
                    await self.handleConnectivityChange(connectivityInfo)
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // Cancel all preloading tasks
        for (_, task) in preloadingTasks {
            task.cancel()
        }
        preloadingTasks.removeAll()
        
        // Clear cancellables
        cancellables.removeAll()
        
        // Clear collections
        syncQueue.removeAll()
        
        print("🧹 HybridContentManager cleanup completed")
    }
    
    private func handleConnectivityChange(_ info: ConnectivityInfo) async {
        print("🔄 Handling connectivity change: \(info.status), Quality: \(info.quality)")
        
        if info.isOnline && syncStatus == .idle {
            // Auto-sync when coming back online
            await syncWhenOnline()
        }
        
        // Cancel preloading if connection becomes poor
        if info.quality == .poor && isPreloading {
            cancelPreloading()
        }
    }
    
    private func setupPreloaders() {
        routeBasedPreloader = RouteBasedPreloader()
        predictivePreloader = PredictivePreloader()
    }
    
    // MARK: - Helper Methods
    
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
}

// MARK: - Supporting Types

enum ContentSource: String, CaseIterable {
    case live = "Live LLM"
    case cached = "Cached LLM"
    case local = "Local"
    
    var icon: String {
        switch self {
        case .live: return "cloud.fill"
        case .cached: return "externaldrive.fill"
        case .local: return "internaldrive.fill"
        }
    }
    
    var description: String { rawValue }
}

enum ContentSelectionStrategy {
    case automatic          // Smart selection based on connectivity
    case forceLive         // Always try live LLM first
    case forceCached       // Prefer cached content
    case forceLocal        // Use only local content
}

enum PreloadingStrategy {
    case priority          // Based on POI importance
    case routeBased       // Based on tour order
    case predictive       // Based on user behavior
    case distance(CLLocation)  // Based on proximity to user
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

struct SyncItem {
    let id: UUID
    let type: SyncItemType
    let data: Data
    let timestamp: Date
}

enum SyncItemType {
    case userPreference
    case bookmark
    case playbackHistory
    case cacheContent
}

// MARK: - Preloader Classes

class RouteBasedPreloader {
    func prioritizePOIs(_ pois: [PointOfInterest], preferences: UserPreferences) -> [PointOfInterest] {
        // Prioritize based on route order and proximity
        return pois.sorted { $0.order < $1.order }
    }
}

class PredictivePreloader {
    func prioritizePOIs(_ pois: [PointOfInterest], preferences: UserPreferences) -> [PointOfInterest] {
        // Use machine learning or heuristics to predict which POIs user is likely to visit
        // For now, use a simple heuristic based on category preferences
        return pois.sorted { poi1, poi2 in
            let score1 = calculatePredictiveScore(for: poi1, preferences: preferences)
            let score2 = calculatePredictiveScore(for: poi2, preferences: preferences)
            return score1 > score2
        }
    }
    
    private func calculatePredictiveScore(for poi: PointOfInterest, preferences: UserPreferences) -> Double {
        var score: Double = 0.0
        
        // Base score from importance
        score += Double(poi.importance.priority) * 10.0
        
        // Add points for certain categories that are typically more popular
        switch poi.category {
        case .landmark, .monument: score += 15.0
        case .museum: score += 12.0
        case .viewpoint: score += 10.0
        case .restaurant: score += 8.0
        case .park: score += 6.0
        default: score += 3.0
        }
        
        return score
    }
}

// MARK: - Error Types

enum HybridContentError: LocalizedError {
    case networkUnavailable
    case cachedContentNotAvailable
    case localContentNotAvailable
    case allContentSourcesFailed
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is not available for live content generation"
        case .cachedContentNotAvailable:
            return "No cached content available for this POI"
        case .localContentNotAvailable:
            return "No local content available for this POI"
        case .allContentSourcesFailed:
            return "All content sources failed to provide content"
        }
    }
}