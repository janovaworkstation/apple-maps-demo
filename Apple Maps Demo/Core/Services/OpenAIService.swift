import Foundation
import Combine

class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.openai.com/v1"
    
    @Published var isGenerating = false
    @Published var currentRequest: URLSessionTask?
    
    private init() {
        // In production, load from secure storage
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func generateAudioContent(
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) async throws -> GeneratedContent {
        isGenerating = true
        defer { isGenerating = false }
        
        let prompt = buildPrompt(for: poi, context: context, preferences: preferences)
        let text = try await generateText(prompt: prompt)
        
        // Use optimal voice for language
        let optimalVoice = MultiLanguageSupport.shared.getOptimalVoiceForLanguage(preferences.preferredLanguage)
        let audioURL = try await generateSpeech(
            text: text, 
            voice: optimalVoice, 
            language: preferences.preferredLanguage
        )
        
        return GeneratedContent(text: text, audioURL: audioURL)
    }
    
    private func generateText(prompt: String) async throws -> String {
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
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return completion.choices.first?.message.content ?? ""
    }
    
    private func generateSpeech(text: String, voice: String, language: String = "en") async throws -> URL {
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
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        // Save audio to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        
        try data.write(to: tempURL)
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