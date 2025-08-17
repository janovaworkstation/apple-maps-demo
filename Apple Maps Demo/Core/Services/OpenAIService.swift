import Foundation
import Combine
import Compression

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.openai.com/v1"
    
    @Published var isGenerating = false
    @Published var currentRequest: URLSessionTask?
    
    // Network optimization
    private let requestBatcher: RequestBatcher
    private let compressionManager: CompressionManager
    private var cancellables = Set<AnyCancellable>()
    
    // Performance metrics
    @Published private(set) var networkStats = NetworkStatistics()
    
    private init() {
        // In production, load from secure storage
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        
        // Configure optimized URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 4
        
        // Enable compression
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate",
            "Content-Encoding": "gzip"
        ]
        
        self.session = URLSession(configuration: config)
        self.requestBatcher = RequestBatcher()
        self.compressionManager = CompressionManager()
        
        Task {
            await setupRequestBatching()
        }
        print("🌐 OpenAIService initialized with network optimizations")
    }
    
    deinit {
        cancellables.removeAll()
        print("🧹 OpenAIService cleanup completed")
    }
    
    func generateAudioContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedContent {
        let startTime = Date()
        
        // Try to batch this request with others
        let request = ContentGenerationRequest(
            poi: poi,
            context: context,
            preferences: preferences
        )
        
        let result = try await requestBatcher.executeRequest(request) { [weak self] batchedRequests in
            guard let self = self else { throw OpenAIError.invalidResponse }
            return try await self.executeBatchedRequests(batchedRequests)
        }
        
        // Update network statistics
        let duration = Date().timeIntervalSince(startTime)
        networkStats.recordRequest(duration: duration, compressed: true)
        
        return result
    }
    
    /// Generate content for multiple POIs in a single optimized request
    func generateBatchedAudioContent(
        for requests: [ContentGenerationRequest]
    ) async throws -> [GeneratedContent] {
        let startTime = Date()
        
        let results = try await executeBatchedRequests(requests)
        
        // Update network statistics
        let duration = Date().timeIntervalSince(startTime)
        networkStats.recordBatchRequest(
            requestCount: requests.count,
            duration: duration,
            compressed: true
        )
        
        return results
    }
    
    // MARK: - Private Implementation
    
    private func setupRequestBatching() async {
        requestBatcher.setBatchingConfiguration(
            maxBatchSize: 5,
            batchTimeout: 2.0
        )
    }
    
    private func executeBatchedRequests(_ requests: [ContentGenerationRequest]) async throws -> [GeneratedContent] {
        guard !requests.isEmpty else { return [] }
        
        if requests.count == 1 {
            // Single request optimization
            let request = requests[0]
            return [try await generateSingleContent(request)]
        } else {
            // Batch multiple requests
            return try await generateBatchedContent(requests)
        }
    }
    
    private func generateSingleContent(_ request: ContentGenerationRequest) async throws -> GeneratedContent {
        isGenerating = true
        defer { isGenerating = false }
        
        let prompt = buildPrompt(for: request.poi, context: request.context, preferences: request.preferences)
        let text = try await generateTextOptimized(prompt: prompt)
        
        // Use optimal voice for language
        let optimalVoice = MultiLanguageSupport.shared.getOptimalVoiceForLanguage(request.preferences.preferredLanguage)
        let audioURL = try await generateSpeechOptimized(
            text: text,
            voice: optimalVoice,
            language: request.preferences.preferredLanguage
        )
        
        return GeneratedContent(text: text, audioURL: audioURL)
    }
    
    private func generateBatchedContent(_ requests: [ContentGenerationRequest]) async throws -> [GeneratedContent] {
        isGenerating = true
        defer { isGenerating = false }
        
        // Generate all text content in a single batch API call
        let prompts = requests.map { buildPrompt(for: $0.poi, context: $0.context, preferences: $0.preferences) }
        let texts = try await generateBatchedText(prompts: prompts)
        
        // Generate audio for all texts
        var results: [GeneratedContent] = []
        
        for (index, text) in texts.enumerated() {
            let request = requests[index]
            let optimalVoice = MultiLanguageSupport.shared.getOptimalVoiceForLanguage(request.preferences.preferredLanguage)
            let audioURL = try await generateSpeechOptimized(
                text: text,
                voice: optimalVoice,
                language: request.preferences.preferredLanguage
            )
            
            results.append(GeneratedContent(text: text, audioURL: audioURL))
        }
        
        return results
    }
    
    private func generateTextOptimized(prompt: String) async throws -> String {
        let endpoint = "\(baseURL)/chat/completions"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4-turbo-preview",
            messages: [
                Message(role: "system", content: "You are an expert tour guide providing engaging, informative audio content for location-based tours."),
                Message(role: "user", content: prompt)
            ],
            temperature: 0.7,
            maxTokens: 500
        )
        
        // Compress request body
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = try compressionManager.compress(jsonData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            networkStats.recordError()
            throw OpenAIError.invalidResponse
        }
        
        // Decompress response if needed
        let decompressedData = try compressionManager.decompress(data)
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: decompressedData)
        
        networkStats.recordDataSaved(
            originalSize: jsonData.count,
            compressedSize: request.httpBody?.count ?? jsonData.count
        )
        
        return completion.choices.first?.message.content ?? ""
    }
    
    private func generateBatchedText(prompts: [String]) async throws -> [String] {
        // Create a single request with multiple prompts
        let batchedPrompt = prompts.enumerated().map { index, prompt in
            "Request \(index + 1): \(prompt)"
        }.joined(separator: "\n\n---\n\n")
        
        let endpoint = "\(baseURL)/chat/completions"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4-turbo-preview",
            messages: [
                Message(role: "system", content: "You are an expert tour guide. Process multiple requests and respond with numbered responses separated by '---SEPARATOR---'."),
                Message(role: "user", content: batchedPrompt)
            ],
            temperature: 0.7,
            maxTokens: 2000 // Increased for batch
        )
        
        // Compress request body
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = try compressionManager.compress(jsonData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            networkStats.recordError()
            throw OpenAIError.invalidResponse
        }
        
        // Decompress and parse response
        let decompressedData = try compressionManager.decompress(data)
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: decompressedData)
        
        networkStats.recordDataSaved(
            originalSize: jsonData.count,
            compressedSize: request.httpBody?.count ?? jsonData.count
        )
        
        let batchedResponse = completion.choices.first?.message.content ?? ""
        return batchedResponse.components(separatedBy: "---SEPARATOR---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private func generateSpeechOptimized(text: String, voice: String, language: String = "en") async throws -> URL {
        let endpoint = "\(baseURL)/audio/speech"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SpeechRequest(
            model: "tts-1-hd",
            input: text,
            voice: voice,
            speed: 1.0
        )
        
        // Compress request body
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = try compressionManager.compress(jsonData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            networkStats.recordError()
            throw OpenAIError.invalidResponse
        }
        
        // Save audio to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        
        try data.write(to: tempURL)
        
        networkStats.recordDataSaved(
            originalSize: jsonData.count,
            compressedSize: request.httpBody?.count ?? jsonData.count
        )
        
        return tempURL
    }
    
    private func buildPrompt(for poi: PointOfInterest, context: TourContext, preferences: UserPreferences) -> String {
        // Use basic prompt building (ContentGenerator removed due to MainActor isolation)
        return buildBasicPrompt(for: poi, context: context, preferences: preferences)
    }
    
    private func selectPromptTemplate(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> PromptTemplate {
        
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
    
    private func buildBasicPrompt(for poi: PointOfInterest, context: TourContext, preferences: UserPreferences) -> String {
        """
        Generate engaging audio narration for a tour stop at "\(poi.name)".
        
        Context:
        - Tour: \(context.tourName)
        - Previous stop: \(context.previousPOI ?? "Starting point")
        - User has been touring for: \(context.elapsedTime) minutes
        - Language: \(preferences.preferredLanguage)
        - Style preference: \(preferences.voiceType.rawValue)
        
        Location details:
        \(poi.poiDescription)
        
        Requirements:
        - Keep it between 60-90 seconds when spoken
        - Be conversational and engaging
        - Include interesting facts or stories
        - Reference the progression of the tour if relevant
        - End with a subtle transition to encourage moving to the next location
        """
    }
}

// MARK: - Supporting Types

struct TourContext {
    let tourName: String
    let previousPOI: String?
    let elapsedTime: Int
    let visitedPOIs: [String]
}

struct GeneratedContent {
    let text: String
    let audioURL: URL
}

enum OpenAIError: LocalizedError {
    case invalidResponse
    case apiKeyMissing
    case networkError(Error)
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiKeyMissing:
            return "OpenAI API key is missing"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .quotaExceeded:
            return "API quota exceeded"
        }
    }
}

// MARK: - API Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
}

struct SpeechRequest: Codable {
    let model: String
    let input: String
    let voice: String
    let speed: Double
}

// MARK: - Network Optimization Classes

struct ContentGenerationRequest {
    let poi: PointOfInterest
    let context: TourContext
    let preferences: UserPreferences
    let id: UUID = UUID()
}

@MainActor
class RequestBatcher {
    private var maxBatchSize = 5
    private var batchTimeout: TimeInterval = 2.0
    private var pendingRequests: [ContentGenerationRequest] = []
    private var pendingContinuations: [CheckedContinuation<GeneratedContent, Error>] = []
    private var batchTimer: Timer?
    
    func setBatchingConfiguration(maxBatchSize: Int, batchTimeout: TimeInterval) {
        self.maxBatchSize = maxBatchSize
        self.batchTimeout = batchTimeout
    }
    
    func executeRequest(
        _ request: ContentGenerationRequest,
        batchExecutor: @escaping ([ContentGenerationRequest]) async throws -> [GeneratedContent]
    ) async throws -> GeneratedContent {
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                pendingRequests.append(request)
                
                if pendingRequests.count >= maxBatchSize {
                    // Execute batch immediately
                    await executeBatch(batchExecutor: batchExecutor, singleContinuation: continuation)
                } else {
                    // Add to pending and set timer
                    pendingContinuations.append(continuation)
                    
                    // Cancel existing timer and set new one
                    batchTimer?.invalidate()
                    batchTimer = Timer.scheduledTimer(withTimeInterval: batchTimeout, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            await self?.executeBatch(batchExecutor: batchExecutor, singleContinuation: nil)
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func executeBatch(
        batchExecutor: @escaping ([ContentGenerationRequest]) async throws -> [GeneratedContent],
        singleContinuation: CheckedContinuation<GeneratedContent, Error>?
    ) async {
        guard !pendingRequests.isEmpty else { return }
        
        let requestsToProcess = pendingRequests
        let continuationsToResolve = pendingContinuations
        
        // Clear pending arrays
        pendingRequests.removeAll()
        pendingContinuations.removeAll()
        batchTimer?.invalidate()
        batchTimer = nil
        
        do {
            let results = try await batchExecutor(requestsToProcess)
            
            // Handle single continuation (for immediate batch execution)
            if let singleContinuation = singleContinuation {
                if let firstResult = results.first {
                    singleContinuation.resume(returning: firstResult)
                } else {
                    singleContinuation.resume(throwing: OpenAIError.invalidResponse)
                }
            }
            
            // Resolve remaining continuations with corresponding results
            for (index, continuation) in continuationsToResolve.enumerated() {
                if index < results.count {
                    continuation.resume(returning: results[index])
                } else {
                    continuation.resume(throwing: OpenAIError.invalidResponse)
                }
            }
        } catch {
            // Resolve single continuation with error
            if let singleContinuation = singleContinuation {
                singleContinuation.resume(throwing: error)
            }
            
            // Resolve all continuations with error
            for continuation in continuationsToResolve {
                continuation.resume(throwing: error)
            }
        }
    }
}

class CompressionManager {
    
    func compress(_ data: Data) throws -> Data {
        // For now, return data as-is
        // In a real implementation, you would use NSData compression or a third-party library
        return data
    }
    
    func decompress(_ data: Data) throws -> Data {
        // For now, return data as-is
        // In a real implementation, you would decompress the data
        return data
    }
}

struct NetworkStatistics {
    private(set) var totalRequests: Int = 0
    private(set) var totalBatchRequests: Int = 0
    private(set) var totalErrors: Int = 0
    private(set) var averageResponseTime: TimeInterval = 0
    private(set) var totalDataSaved: Int64 = 0
    private(set) var compressionRatio: Double = 0
    
    mutating func recordRequest(duration: TimeInterval, compressed: Bool) {
        totalRequests += 1
        averageResponseTime = (averageResponseTime * Double(totalRequests - 1) + duration) / Double(totalRequests)
    }
    
    mutating func recordBatchRequest(requestCount: Int, duration: TimeInterval, compressed: Bool) {
        totalBatchRequests += 1
        totalRequests += requestCount
        averageResponseTime = (averageResponseTime * Double(totalRequests - requestCount) + duration) / Double(totalRequests)
    }
    
    mutating func recordError() {
        totalErrors += 1
    }
    
    mutating func recordDataSaved(originalSize: Int, compressedSize: Int) {
        let savedBytes = originalSize - compressedSize
        totalDataSaved += Int64(savedBytes)
        
        if originalSize > 0 {
            compressionRatio = Double(compressedSize) / Double(originalSize)
        }
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - totalErrors) / Double(totalRequests)
    }
    
    var formattedDataSaved: String {
        ByteCountFormatter().string(fromByteCount: totalDataSaved)
    }
}