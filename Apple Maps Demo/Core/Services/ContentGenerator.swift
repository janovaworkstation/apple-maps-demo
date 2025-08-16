import Foundation
import Combine

// MARK: - ContentGenerator Service

@MainActor
class ContentGenerator: ObservableObject {
    static let shared = ContentGenerator()
    
    private let openAIService: OpenAIService
    private let cacheManager: ContentCacheManager
    private let validator: ContentValidator
    
    @Published var isGenerating = false
    @Published var cacheHitRate: Double = 0.0
    
    private init() {
        self.openAIService = OpenAIService.shared
        self.cacheManager = ContentCacheManager()
        self.validator = ContentValidator()
    }
    
    // MARK: - Public Interface
    
    func generateContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences,
        forceRegenerate: Bool = false
    ) async throws -> GeneratedAudioContent {
        
        isGenerating = true
        defer { isGenerating = false }
        
        // Check cache first (unless forced regeneration)
        if !forceRegenerate,
           let cachedContent = await cacheManager.getCachedContent(
            for: poi,
            context: context,
            preferences: preferences
           ) {
            print("📋 Using cached content for POI: \(poi.name)")
            await updateCacheHitRate()
            return cachedContent
        }
        
        // Generate new content
        let template = selectPromptTemplate(for: poi, context: context, preferences: preferences)
        _ = template.buildPrompt(poi: poi, context: context, preferences: preferences)
        
        let generatedContent = try await openAIService.generateAudioContent(
            for: poi,
            context: context,
            preferences: preferences
        )
        
        // Validate generated content
        let validatedContent = try await validator.validateContent(generatedContent, for: poi)
        
        // Create enhanced audio content object
        let audioContent = GeneratedAudioContent(
            id: UUID(),
            poiId: poi.id,
            text: validatedContent.text,
            audioURL: validatedContent.audioURL,
            template: template.type,
            language: preferences.preferredLanguage,
            generatedAt: Date(),
            quality: validatedContent.quality,
            durationEstimate: estimateSpeechDuration(validatedContent.text),
            cacheKey: buildCacheKey(poi: poi, context: context, preferences: preferences)
        )
        
        // Cache the validated content
        await cacheManager.cacheContent(audioContent, for: poi, context: context, preferences: preferences)
        
        print("✨ Generated new content for POI: \(poi.name)")
        await updateCacheHitRate()
        
        return audioContent
    }
    
    // MARK: - Template Selection
    
    private func selectPromptTemplate(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> PromptTemplate {
        
        // Select template based on POI category and context
        switch poi.category {
        case .landmark, .monument:
            return HistoricalPromptTemplate()
        case .museum:
            return CulturalPromptTemplate()
        case .restaurant:
            return CulinaryPromptTemplate()
        case .park, .viewpoint:
            return NaturalPromptTemplate()
        case .building:
            return ArchitecturalPromptTemplate()
        case .general:
            return context.visitedPOIs.count > 2 ? 
                PersonalizedPromptTemplate() : 
                GeneralPromptTemplate()
        default:
            return GeneralPromptTemplate()
        }
    }
    
    // MARK: - Utility Methods
    
    private func estimateSpeechDuration(_ text: String) -> TimeInterval {
        // Average speaking rate: ~150 words per minute
        let wordsPerMinute: Double = 150
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        return (Double(wordCount) / wordsPerMinute) * 60
    }
    
    private func buildCacheKey(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        let poiKey = "\(poi.id.uuidString)_\(poi.category.rawValue)"
        let contextKey = "\(context.tourName)_\(context.visitedPOIs.count)"
        let prefsKey = "\(preferences.preferredLanguage)_\(preferences.voiceType.rawValue)"
        return "\(poiKey)_\(contextKey)_\(prefsKey)".md5Hash
    }
    
    private func updateCacheHitRate() async {
        cacheHitRate = await cacheManager.getCacheHitRate()
    }
    
    // MARK: - Cache Management
    
    func clearCache() async {
        await cacheManager.clearCache()
        await updateCacheHitRate()
    }
    
    func getCacheStatistics() async -> ContentCacheStatistics {
        return await cacheManager.getStatistics()
    }
    
    func optimizeCache() async {
        await cacheManager.optimizeCache()
        await updateCacheHitRate()
    }
}

// MARK: - Enhanced Generated Content Model

struct GeneratedAudioContent {
    let id: UUID
    let poiId: UUID
    let text: String
    let audioURL: URL
    let template: PromptTemplateType
    let language: String
    let generatedAt: Date
    let quality: ContentQuality
    let durationEstimate: TimeInterval
    let cacheKey: String
    
    var isValid: Bool {
        return !text.isEmpty && 
               FileManager.default.fileExists(atPath: audioURL.path) &&
               durationEstimate >= 45 && durationEstimate <= 120 // 45-120 seconds
    }
}

// MARK: - Supporting Types

enum PromptTemplateType: String, CaseIterable {
    case historical = "historical"
    case cultural = "cultural"
    case culinary = "culinary"
    case natural = "natural"
    case architectural = "architectural"
    case personalized = "personalized"
    case general = "general"
}

enum ContentQuality: Int, CaseIterable {
    case poor = 1
    case fair = 2
    case good = 3
    case excellent = 4
    
    var description: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

// MARK: - String Extension for Cache Keys

extension String {
    var md5Hash: String {
        // Simple hash for cache keys - in production, use CryptoKit
        return String(self.hash)
    }
}