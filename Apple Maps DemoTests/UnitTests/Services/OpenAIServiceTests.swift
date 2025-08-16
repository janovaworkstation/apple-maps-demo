//
//  OpenAIServiceTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import Foundation
@testable import Apple_Maps_Demo

final class OpenAIServiceTests: XCTestCase {
    
    var mockOpenAIService: MockOpenAIService!
    var testPOI: PointOfInterest!
    var testPromptTemplate: PromptTemplate!
    var testLocationContext: LocationContext!
    var testUserPreferences: UserPreferences!
    
    override func setUpWithError() throws {
        super.setUp()
        
        mockOpenAIService = MockOpenAIService()
        testPOI = TestDataFactory.createPOI(name: "Golden Gate Bridge")
        testUserPreferences = TestDataFactory.createUserPreferences()
        testLocationContext = LocationContext.mock()
        
        // Create a test prompt template
        testPromptTemplate = PromptTemplate(
            id: UUID(),
            type: .historical,
            template: "Tell me about {POI_NAME} at {LOCATION}",
            language: "en",
            variables: ["POI_NAME", "LOCATION"]
        )
    }
    
    override func tearDownWithError() throws {
        mockOpenAIService?.reset()
        mockOpenAIService = nil
        testPOI = nil
        testPromptTemplate = nil
        testLocationContext = nil
        testUserPreferences = nil
        super.tearDown()
    }
    
    // MARK: - Audio Content Generation Tests
    
    func testGenerateAudioContentSuccess() async throws {
        XCTAssertEqual(mockOpenAIService.generateAudioContentCallCount, 0)
        
        let audioContent = try await mockOpenAIService.generateAudioContent(
            for: testPOI,
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        XCTAssertEqual(mockOpenAIService.generateAudioContentCallCount, 1)
        XCTAssertNotNil(audioContent)
        XCTAssertTrue(audioContent.isLLMGenerated)
        XCTAssertEqual(audioContent.language, testUserPreferences.preferredLanguage)
        XCTAssertEqual(audioContent.transcript, mockOpenAIService.mockTextResponse)
        XCTAssertGreaterThan(audioContent.duration, 0)
    }
    
    func testGenerateAudioContentError() async {
        mockOpenAIService.simulateError(MockOpenAIError.requestFailed)
        
        do {
            _ = try await mockOpenAIService.generateAudioContent(
                for: testPOI,
                using: testPromptTemplate,
                locationContext: testLocationContext,
                preferences: testUserPreferences
            )
            XCTFail("Expected error to be thrown")
        } catch let error as MockOpenAIError {
            XCTAssertEqual(error, MockOpenAIError.requestFailed)
            XCTAssertEqual(mockOpenAIService.generateAudioContentCallCount, 1)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testGenerateAudioContentNetworkError() async {
        mockOpenAIService.simulateNetworkError()
        
        do {
            _ = try await mockOpenAIService.generateAudioContent(
                for: testPOI,
                using: testPromptTemplate,
                locationContext: testLocationContext,
                preferences: testUserPreferences
            )
            XCTFail("Expected network error")
        } catch let error as MockOpenAIError {
            XCTAssertEqual(error, MockOpenAIError.networkError)
        }
    }
    
    func testGenerateAudioContentRateLimitError() async {
        mockOpenAIService.simulateRateLimitError()
        
        do {
            _ = try await mockOpenAIService.generateAudioContent(
                for: testPOI,
                using: testPromptTemplate,
                locationContext: testLocationContext,
                preferences: testUserPreferences
            )
            XCTFail("Expected rate limit error")
        } catch let error as MockOpenAIError {
            XCTAssertEqual(error, MockOpenAIError.rateLimitExceeded)
        }
    }
    
    // MARK: - Text Content Generation Tests
    
    func testGenerateTextContentSuccess() async throws {
        XCTAssertEqual(mockOpenAIService.generateTextContentCallCount, 0)
        
        let textContent = try await mockOpenAIService.generateTextContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        XCTAssertEqual(mockOpenAIService.generateTextContentCallCount, 1)
        XCTAssertEqual(textContent, mockOpenAIService.mockTextResponse)
        XCTAssertFalse(textContent.isEmpty)
    }
    
    func testGenerateTextContentError() async {
        mockOpenAIService.simulateError(MockOpenAIError.invalidAPIKey)
        
        do {
            _ = try await mockOpenAIService.generateTextContent(
                using: testPromptTemplate,
                locationContext: testLocationContext,
                preferences: testUserPreferences
            )
            XCTFail("Expected error to be thrown")
        } catch let error as MockOpenAIError {
            XCTAssertEqual(error, MockOpenAIError.invalidAPIKey)
        }
    }
    
    func testGenerateTextContentWithCustomResponse() async throws {
        let customResponse = "This is a custom response about the Golden Gate Bridge."
        mockOpenAIService.setMockResponse(text: customResponse)
        
        let textContent = try await mockOpenAIService.generateTextContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        XCTAssertEqual(textContent, customResponse)
    }
    
    // MARK: - Streaming Content Tests
    
    func testStreamContentSuccess() async throws {
        XCTAssertEqual(mockOpenAIService.streamContentCallCount, 0)
        
        let streamingContent = mockOpenAIService.streamContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        var receivedChunks: [String] = []
        
        do {
            for try await chunk in streamingContent {
                receivedChunks.append(chunk)
            }
        } catch {
            XCTFail("Streaming should not fail: \(error)")
        }
        
        XCTAssertEqual(mockOpenAIService.streamContentCallCount, 1)
        XCTAssertEqual(receivedChunks.count, mockOpenAIService.mockStreamingResponses.count)
        XCTAssertEqual(receivedChunks, mockOpenAIService.mockStreamingResponses)
    }
    
    func testStreamContentError() async {
        mockOpenAIService.simulateError(MockOpenAIError.contentFiltered)
        
        let streamingContent = mockOpenAIService.streamContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        do {
            for try await _ in streamingContent {
                XCTFail("Should not receive any chunks")
            }
        } catch let error as MockOpenAIError {
            XCTAssertEqual(error, MockOpenAIError.contentFiltered)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testStreamContentCustomChunks() async throws {
        let customChunks = ["Chunk A", "Chunk B", "Chunk C", "Final chunk"]
        mockOpenAIService.setMockStreamingResponse(customChunks)
        
        let streamingContent = mockOpenAIService.streamContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        var receivedChunks: [String] = []
        
        for try await chunk in streamingContent {
            receivedChunks.append(chunk)
        }
        
        XCTAssertEqual(receivedChunks, customChunks)
    }
    
    // MARK: - Text-to-Speech Tests
    
    func testConvertTextToSpeechSuccess() async throws {
        let testText = "This is a test text for speech conversion."
        let voice = VoiceType.female
        let language = "en"
        
        let audioData = try await mockOpenAIService.convertTextToSpeech(
            text: testText,
            voice: voice,
            language: language
        )
        
        XCTAssertEqual(audioData, mockOpenAIService.mockAudioData)
        XCTAssertGreaterThan(audioData.count, 0)
    }
    
    func testConvertTextToSpeechError() async {
        mockOpenAIService.simulateError(MockOpenAIError.ttsServiceUnavailable)
        
        do {
            _ = try await mockOpenAIService.convertTextToSpeech(
                text: "Test text",
                voice: .default,
                language: "en"
            )
            XCTFail("Expected TTS error")
        } catch let error as MockOpenAIError {
            XCTAssertEqual(error, MockOpenAIError.ttsServiceUnavailable)
        }
    }
    
    func testConvertTextToSpeechWithCustomAudioData() async throws {
        let customAudioData = Data("Custom audio data for testing".utf8)
        mockOpenAIService.setMockAudioData(customAudioData)
        
        let audioData = try await mockOpenAIService.convertTextToSpeech(
            text: "Test text",
            voice: .male,
            language: "es"
        )
        
        XCTAssertEqual(audioData, customAudioData)
    }
    
    // MARK: - Request Tracking Tests
    
    func testRequestParameterTracking() async throws {
        _ = try await mockOpenAIService.generateAudioContent(
            for: testPOI,
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        XCTAssertEqual(mockOpenAIService.lastPromptTemplate?.id, testPromptTemplate.id)
        XCTAssertEqual(mockOpenAIService.lastLocationContext?.currentLocation, testLocationContext.currentLocation)
        XCTAssertEqual(mockOpenAIService.lastUserPreferences?.preferredLanguage, testUserPreferences.preferredLanguage)
    }
    
    func testMultipleRequestTracking() async throws {
        // First request
        _ = try await mockOpenAIService.generateTextContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        // Second request with different parameters
        let newPreferences = TestDataFactory.createUserPreferences(preferredLanguage: "es")
        _ = try await mockOpenAIService.generateTextContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: newPreferences
        )
        
        // Should track the latest request
        XCTAssertEqual(mockOpenAIService.lastUserPreferences?.preferredLanguage, "es")
        XCTAssertEqual(mockOpenAIService.generateTextContentCallCount, 2)
    }
    
    // MARK: - Network Delay Simulation Tests
    
    func testNetworkDelaySimulation() async throws {
        let delayTime: TimeInterval = 0.5
        mockOpenAIService.simulateNetworkDelay(delayTime)
        
        let startTime = Date()
        
        _ = try await mockOpenAIService.generateTextContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        let endTime = Date()
        let actualDelay = endTime.timeIntervalSince(startTime)
        
        XCTAssertGreaterThanOrEqual(actualDelay, delayTime * 0.9) // Allow some variance
    }
    
    func testStreamingDelaySimulation() async throws {
        let delayTime: TimeInterval = 0.2
        mockOpenAIService.simulateNetworkDelay(delayTime)
        
        let streamingContent = mockOpenAIService.streamContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        var chunkTimes: [Date] = []
        let startTime = Date()
        
        for try await _ in streamingContent {
            chunkTimes.append(Date())
        }
        
        // Verify chunks arrived with delays
        if chunkTimes.count >= 2 {
            let timeBetweenChunks = chunkTimes[1].timeIntervalSince(chunkTimes[0])
            XCTAssertGreaterThanOrEqual(timeBetweenChunks, delayTime * 0.9)
        }
    }
    
    // MARK: - Error Type Tests
    
    func testAllErrorTypes() async {
        let errorTypes: [MockOpenAIError] = [
            .requestFailed,
            .invalidAPIKey,
            .rateLimitExceeded,
            .networkError,
            .ttsServiceUnavailable,
            .invalidPrompt,
            .contentFiltered
        ]
        
        for errorType in errorTypes {
            mockOpenAIService.reset()
            mockOpenAIService.simulateError(errorType)
            
            do {
                _ = try await mockOpenAIService.generateTextContent(
                    using: testPromptTemplate,
                    locationContext: testLocationContext,
                    preferences: testUserPreferences
                )
                XCTFail("Expected error \(errorType) to be thrown")
            } catch let error as MockOpenAIError {
                XCTAssertEqual(error, errorType)
            } catch {
                XCTFail("Unexpected error type for \(errorType): \(error)")
            }
        }
    }
    
    // MARK: - Mock Configuration Tests
    
    func testMockResponseConfiguration() async throws {
        let customResponses = [
            "Custom response 1",
            "Another custom response",
            "Third response with special characters: é, ñ, 中文"
        ]
        
        for customResponse in customResponses {
            mockOpenAIService.setMockResponse(text: customResponse)
            
            let response = try await mockOpenAIService.generateTextContent(
                using: testPromptTemplate,
                locationContext: testLocationContext,
                preferences: testUserPreferences
            )
            
            XCTAssertEqual(response, customResponse)
        }
    }
    
    func testMockAudioDataConfiguration() async throws {
        let customAudioDataStrings = [
            "Audio data 1",
            "Different audio content",
            "More audio data with special chars: 🎵🎶"
        ]
        
        for audioString in customAudioDataStrings {
            let customAudioData = Data(audioString.utf8)
            mockOpenAIService.setMockAudioData(customAudioData)
            
            let audioData = try await mockOpenAIService.convertTextToSpeech(
                text: "Test text",
                voice: .default,
                language: "en"
            )
            
            XCTAssertEqual(audioData, customAudioData)
        }
    }
    
    // MARK: - Mock Reset Tests
    
    func testMockReset() async throws {
        // Set up some state
        mockOpenAIService.setMockResponse(text: "Custom response")
        mockOpenAIService.simulateNetworkDelay(1.0)
        mockOpenAIService.simulateError(MockOpenAIError.networkError)
        
        // Make a request to increment counters
        do {
            _ = try await mockOpenAIService.generateTextContent(
                using: testPromptTemplate,
                locationContext: testLocationContext,
                preferences: testUserPreferences
            )
        } catch {
            // Expected due to simulated error
        }
        
        XCTAssertEqual(mockOpenAIService.generateTextContentCallCount, 1)
        XCTAssertNotNil(mockOpenAIService.lastPromptTemplate)
        
        // Reset
        mockOpenAIService.reset()
        
        // Verify reset state
        XCTAssertEqual(mockOpenAIService.generateTextContentCallCount, 0)
        XCTAssertEqual(mockOpenAIService.generateAudioContentCallCount, 0)
        XCTAssertEqual(mockOpenAIService.streamContentCallCount, 0)
        XCTAssertNil(mockOpenAIService.lastPromptTemplate)
        XCTAssertNil(mockOpenAIService.lastLocationContext)
        XCTAssertNil(mockOpenAIService.lastUserPreferences)
        XCTAssertFalse(mockOpenAIService.shouldFailRequest)
        XCTAssertEqual(mockOpenAIService.responseDelay, 0.1)
        
        // Verify it works after reset
        let response = try await mockOpenAIService.generateTextContent(
            using: testPromptTemplate,
            locationContext: testLocationContext,
            preferences: testUserPreferences
        )
        
        XCTAssertFalse(response.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testMultipleRequestsPerformance() async throws {
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<10 {
                group.enter()
                Task {
                    do {
                        _ = try await mockOpenAIService.generateTextContent(
                            using: testPromptTemplate,
                            locationContext: testLocationContext,
                            preferences: testUserPreferences
                        )
                    } catch {
                        // Ignore errors for performance test
                    }
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    func testStreamingPerformance() async throws {
        let largeChunkCount = 100
        let largeChunks = (0..<largeChunkCount).map { "Chunk \($0)" }
        mockOpenAIService.setMockStreamingResponse(largeChunks)
        mockOpenAIService.simulateNetworkDelay(0.001) // Minimal delay
        
        measure {
            Task {
                let streamingContent = mockOpenAIService.streamContent(
                    using: testPromptTemplate,
                    locationContext: testLocationContext,
                    preferences: testUserPreferences
                )
                
                var count = 0
                do {
                    for try await _ in streamingContent {
                        count += 1
                    }
                } catch {
                    // Ignore errors for performance test
                }
                
                XCTAssertEqual(count, largeChunkCount)
            }
        }
    }
}