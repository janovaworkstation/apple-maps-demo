//
//  MockOpenAIService.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import Foundation
import Combine
import CoreLocation
@testable import Apple_Maps_Demo

final class MockOpenAIService {
    
    // MARK: - Mock State
    var generateAudioContentCallCount = 0
    var generateTextContentCallCount = 0
    var streamContentCallCount = 0
    
    var shouldFailRequest = false
    var mockError: Error?
    var responseDelay: TimeInterval = 0.1
    
    // Mock response data
    var mockTextResponse = "This is a mock generated text response for the tour."
    var mockAudioData = Data("mock audio data".utf8)
    var mockStreamingResponses: [String] = ["Chunk 1", "Chunk 2", "Chunk 3"]
    
    // Request tracking
    var lastPromptTemplate: PromptTemplate?
    var lastLocationContext: LocationContext?
    var lastUserPreferences: UserPreferences?
    
    // MARK: - Mock Implementation
    
    func generateAudioContent(
        for poi: PointOfInterest,
        using template: PromptTemplate,
        locationContext: LocationContext,
        preferences: UserPreferences
    ) async throws -> AudioContent {
        
        generateAudioContentCallCount += 1
        lastPromptTemplate = template
        lastLocationContext = locationContext
        lastUserPreferences = preferences
        
        if shouldFailRequest {
            throw mockError ?? MockOpenAIError.requestFailed
        }
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        return AudioContent(
            id: UUID(),
            localFileURL: nil,
            transcript: mockTextResponse,
            duration: 120,
            isLLMGenerated: true,
            cachedAt: Date(),
            language: preferences.preferredLanguage,
            quality: .medium,
            fileSize: mockAudioData.count,
            format: .mp3
        )
    }
    
    func generateTextContent(
        using template: PromptTemplate,
        locationContext: LocationContext,
        preferences: UserPreferences
    ) async throws -> String {
        
        generateTextContentCallCount += 1
        lastPromptTemplate = template
        lastLocationContext = locationContext
        lastUserPreferences = preferences
        
        if shouldFailRequest {
            throw mockError ?? MockOpenAIError.requestFailed
        }
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        return mockTextResponse
    }
    
    func streamContent(
        using template: PromptTemplate,
        locationContext: LocationContext,
        preferences: UserPreferences
    ) -> AsyncThrowingStream<String, Error> {
        
        streamContentCallCount += 1
        lastPromptTemplate = template
        lastLocationContext = locationContext
        lastUserPreferences = preferences
        
        return AsyncThrowingStream { continuation in
            Task {
                if shouldFailRequest {
                    continuation.finish(throwing: mockError ?? MockOpenAIError.requestFailed)
                    return
                }
                
                for chunk in mockStreamingResponses {
                    try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
                    continuation.yield(chunk)
                }
                
                continuation.finish()
            }
        }
    }
    
    // MARK: - Text-to-Speech Mock
    
    func convertTextToSpeech(
        text: String,
        voice: VoiceType,
        language: String
    ) async throws -> Data {
        
        if shouldFailRequest {
            throw mockError ?? MockOpenAIError.ttsServiceUnavailable
        }
        
        // Simulate TTS processing delay
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        return mockAudioData
    }
    
    // MARK: - Mock Configuration
    
    func setMockResponse(text: String) {
        mockTextResponse = text
    }
    
    func setMockAudioData(_ data: Data) {
        mockAudioData = data
    }
    
    func setMockStreamingResponse(_ chunks: [String]) {
        mockStreamingResponses = chunks
    }
    
    func simulateNetworkDelay(_ delay: TimeInterval) {
        responseDelay = delay
    }
    
    func simulateError(_ error: Error) {
        mockError = error
        shouldFailRequest = true
    }
    
    func simulateRateLimitError() {
        simulateError(MockOpenAIError.rateLimitExceeded)
    }
    
    func simulateNetworkError() {
        simulateError(MockOpenAIError.networkError)
    }
    
    func simulateAuthenticationError() {
        simulateError(MockOpenAIError.invalidAPIKey)
    }
    
    // MARK: - Reset Mock State
    
    func reset() {
        generateAudioContentCallCount = 0
        generateTextContentCallCount = 0
        streamContentCallCount = 0
        
        shouldFailRequest = false
        mockError = nil
        responseDelay = 0.1
        
        mockTextResponse = "This is a mock generated text response for the tour."
        mockAudioData = Data("mock audio data".utf8)
        mockStreamingResponses = ["Chunk 1", "Chunk 2", "Chunk 3"]
        
        lastPromptTemplate = nil
        lastLocationContext = nil
        lastUserPreferences = nil
    }
}

// MARK: - Mock Errors

enum MockOpenAIError: Error, LocalizedError {
    case requestFailed
    case invalidAPIKey
    case rateLimitExceeded
    case networkError
    case ttsServiceUnavailable
    case invalidPrompt
    case contentFiltered
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Mock request failed"
        case .invalidAPIKey:
            return "Mock invalid API key"
        case .rateLimitExceeded:
            return "Mock rate limit exceeded"
        case .networkError:
            return "Mock network error"
        case .ttsServiceUnavailable:
            return "Mock TTS service unavailable"
        case .invalidPrompt:
            return "Mock invalid prompt"
        case .contentFiltered:
            return "Mock content filtered"
        }
    }
}

// MARK: - Mock Context Types

struct LocationContext {
    let currentLocation: CLLocation?
    let nearbyPOIs: [PointOfInterest]
    let historicalVisits: [CLVisit]
    let currentWeather: String?
    let timeOfDay: String
}

extension LocationContext {
    static func mock(
        currentLocation: CLLocation? = TestDataFactory.createLocation(),
        nearbyPOIs: [PointOfInterest] = TestDataFactory.samplePOIs,
        timeOfDay: String = "afternoon"
    ) -> LocationContext {
        return LocationContext(
            currentLocation: currentLocation,
            nearbyPOIs: nearbyPOIs,
            historicalVisits: [],
            currentWeather: "sunny",
            timeOfDay: timeOfDay
        )
    }
}