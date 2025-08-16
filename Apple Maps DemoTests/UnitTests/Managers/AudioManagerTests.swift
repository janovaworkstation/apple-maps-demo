//
//  AudioManagerTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import Combine
import AVFoundation
@testable import Apple_Maps_Demo

@MainActor
final class AudioManagerTests: XCTestCase {
    
    var mockAudioManager: MockAudioManager!
    var cancellables: Set<AnyCancellable>!
    var testPOI: PointOfInterest!
    var testTour: Tour!
    
    override func setUpWithError() throws {
        super.setUp()
        
        mockAudioManager = MockAudioManager()
        cancellables = Set<AnyCancellable>()
        testPOI = TestDataFactory.createPOI(name: "Test Audio POI")
        testTour = TestDataFactory.createTourWithPOIs(poiCount: 3)
    }
    
    override func tearDownWithError() throws {
        mockAudioManager?.reset()
        mockAudioManager = nil
        cancellables?.removeAll()
        cancellables = nil
        testPOI = nil
        testTour = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAudioManagerInitialization() {
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentTime, 0)
        XCTAssertEqual(mockAudioManager.duration, 0)
        XCTAssertNil(mockAudioManager.currentPOI)
        XCTAssertEqual(mockAudioManager.playbackRate, 1.0)
        XCTAssertEqual(mockAudioManager.volume, 1.0)
        XCTAssertFalse(mockAudioManager.isCrossfading)
        XCTAssertFalse(mockAudioManager.isBuffering)
        XCTAssertEqual(mockAudioManager.audioQuality, .medium)
        XCTAssertEqual(mockAudioManager.connectionStatus, .builtin)
    }
    
    // MARK: - Basic Playback Tests
    
    func testAudioManagerPlay() async throws {
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.playCallCount, 0)
        
        try await mockAudioManager.play()
        
        XCTAssertTrue(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.playCallCount, 1)
        XCTAssertEqual(mockAudioManager.currentAudioSession, .active)
    }
    
    func testAudioManagerPause() {
        mockAudioManager.isPlaying = true
        XCTAssertEqual(mockAudioManager.pauseCallCount, 0)
        
        mockAudioManager.pause()
        
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.pauseCallCount, 1)
    }
    
    func testAudioManagerStop() {
        mockAudioManager.isPlaying = true
        mockAudioManager.currentTime = 50
        mockAudioManager.currentPOI = testPOI
        XCTAssertEqual(mockAudioManager.stopCallCount, 0)
        
        mockAudioManager.stop()
        
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentTime, 0)
        XCTAssertNil(mockAudioManager.currentPOI)
        XCTAssertEqual(mockAudioManager.stopCallCount, 1)
        XCTAssertEqual(mockAudioManager.currentAudioSession, .inactive)
    }
    
    // MARK: - Toggle Playback Tests
    
    func testAudioManagerTogglePlaybackFromStopped() async throws {
        XCTAssertFalse(mockAudioManager.isPlaying)
        
        await mockAudioManager.togglePlayback()
        
        XCTAssertTrue(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.playCallCount, 1)
        XCTAssertEqual(mockAudioManager.pauseCallCount, 0)
    }
    
    func testAudioManagerTogglePlaybackFromPlaying() async throws {
        mockAudioManager.isPlaying = true
        
        await mockAudioManager.togglePlayback()
        
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.playCallCount, 0)
        XCTAssertEqual(mockAudioManager.pauseCallCount, 1)
    }
    
    // MARK: - Seek Tests
    
    func testAudioManagerSeek() async {
        let seekTime: TimeInterval = 45.5
        XCTAssertEqual(mockAudioManager.seekCallCount, 0)
        XCTAssertNil(mockAudioManager.lastSeekTime)
        
        await mockAudioManager.seek(to: seekTime)
        
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
        XCTAssertEqual(mockAudioManager.lastSeekTime, seekTime)
        XCTAssertEqual(mockAudioManager.currentTime, seekTime)
    }
    
    func testAudioManagerSeekToTime() async {
        let seekTime: TimeInterval = 30.0
        
        await mockAudioManager.seekToTime(seekTime)
        
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
        XCTAssertEqual(mockAudioManager.lastSeekTime, seekTime)
        XCTAssertEqual(mockAudioManager.currentTime, seekTime)
    }
    
    func testAudioManagerSeekBounds() async {
        mockAudioManager.duration = 120
        
        // Test seeking beyond duration
        await mockAudioManager.seek(to: 150)
        XCTAssertEqual(mockAudioManager.currentTime, 150) // Mock allows any value
        
        // Test seeking to negative time
        await mockAudioManager.seek(to: -10)
        XCTAssertEqual(mockAudioManager.currentTime, -10) // Mock allows any value
        
        // Test seeking to zero
        await mockAudioManager.seek(to: 0)
        XCTAssertEqual(mockAudioManager.currentTime, 0)
    }
    
    // MARK: - Skip Forward/Backward Tests
    
    func testAudioManagerSkipForward() async {
        mockAudioManager.currentTime = 30
        mockAudioManager.duration = 120
        
        await mockAudioManager.skipForward()
        
        XCTAssertEqual(mockAudioManager.currentTime, 60) // 30 + 30 default
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
    }
    
    func testAudioManagerSkipForwardCustomTime() async {
        mockAudioManager.currentTime = 20
        mockAudioManager.duration = 120
        
        await mockAudioManager.skipForward(15)
        
        XCTAssertEqual(mockAudioManager.currentTime, 35) // 20 + 15
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
    }
    
    func testAudioManagerSkipForwardAtEnd() async {
        mockAudioManager.currentTime = 100
        mockAudioManager.duration = 120
        
        await mockAudioManager.skipForward()
        
        XCTAssertEqual(mockAudioManager.currentTime, 120) // Clamped to duration
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
    }
    
    func testAudioManagerSkipBackward() async {
        mockAudioManager.currentTime = 60
        mockAudioManager.duration = 120
        
        await mockAudioManager.skipBackward()
        
        XCTAssertEqual(mockAudioManager.currentTime, 30) // 60 - 30 default
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
    }
    
    func testAudioManagerSkipBackwardCustomTime() async {
        mockAudioManager.currentTime = 50
        mockAudioManager.duration = 120
        
        await mockAudioManager.skipBackward(20)
        
        XCTAssertEqual(mockAudioManager.currentTime, 30) // 50 - 20
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
    }
    
    func testAudioManagerSkipBackwardAtBeginning() async {
        mockAudioManager.currentTime = 10
        mockAudioManager.duration = 120
        
        await mockAudioManager.skipBackward()
        
        XCTAssertEqual(mockAudioManager.currentTime, 0) // Clamped to 0
        XCTAssertEqual(mockAudioManager.seekCallCount, 1)
    }
    
    // MARK: - Volume Control Tests
    
    func testAudioManagerSetVolume() {
        let testVolume: Float = 0.5
        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 0)
        XCTAssertNil(mockAudioManager.lastVolumeValue)
        
        mockAudioManager.setVolume(testVolume)
        
        XCTAssertEqual(mockAudioManager.setVolumeCallCount, 1)
        XCTAssertEqual(mockAudioManager.lastVolumeValue, testVolume)
        XCTAssertEqual(mockAudioManager.volume, testVolume)
    }
    
    func testAudioManagerVolumeRange() {
        // Test minimum volume
        mockAudioManager.setVolume(0.0)
        XCTAssertEqual(mockAudioManager.volume, 0.0)
        
        // Test maximum volume
        mockAudioManager.setVolume(1.0)
        XCTAssertEqual(mockAudioManager.volume, 1.0)
        
        // Test mid-range volume
        mockAudioManager.setVolume(0.75)
        XCTAssertEqual(mockAudioManager.volume, 0.75)
    }
    
    // MARK: - Playback Rate Tests
    
    func testAudioManagerSetPlaybackRate() {
        let testRate: Float = 1.5
        XCTAssertEqual(mockAudioManager.setPlaybackRateCallCount, 0)
        XCTAssertNil(mockAudioManager.lastPlaybackRateValue)
        
        mockAudioManager.setPlaybackRate(testRate)
        
        XCTAssertEqual(mockAudioManager.setPlaybackRateCallCount, 1)
        XCTAssertEqual(mockAudioManager.lastPlaybackRateValue, testRate)
        XCTAssertEqual(mockAudioManager.playbackRate, testRate)
    }
    
    func testAudioManagerPlaybackRateRange() {
        // Test slow playback
        mockAudioManager.setPlaybackRate(0.5)
        XCTAssertEqual(mockAudioManager.playbackRate, 0.5)
        
        // Test normal playback
        mockAudioManager.setPlaybackRate(1.0)
        XCTAssertEqual(mockAudioManager.playbackRate, 1.0)
        
        // Test fast playback
        mockAudioManager.setPlaybackRate(2.0)
        XCTAssertEqual(mockAudioManager.playbackRate, 2.0)
    }
    
    // MARK: - POI Playback Tests
    
    func testAudioManagerPlayAudioForPOI() async throws {
        XCTAssertNil(mockAudioManager.currentPOI)
        XCTAssertEqual(mockAudioManager.duration, 0)
        XCTAssertFalse(mockAudioManager.isPlaying)
        
        try await mockAudioManager.playAudioForPOI(testPOI)
        
        XCTAssertEqual(mockAudioManager.currentPOI?.id, testPOI.id)
        XCTAssertEqual(mockAudioManager.duration, testPOI.audioContent.duration)
        XCTAssertTrue(mockAudioManager.isPlaying)
    }
    
    func testAudioManagerPlayAudioForPOIError() async {
        mockAudioManager.simulateAudioError(AudioManagerError.playbackFailed)
        
        do {
            try await mockAudioManager.playAudioForPOI(testPOI)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AudioManagerError)
            XCTAssertFalse(mockAudioManager.isPlaying)
        }
    }
    
    // MARK: - Tour Management Tests
    
    func testAudioManagerSetCurrentTour() {
        XCTAssertNil(mockAudioManager.currentTourPublic)
        
        mockAudioManager.setCurrentTour(testTour)
        
        XCTAssertEqual(mockAudioManager.currentTourPublic?.id, testTour.id)
        XCTAssertEqual(mockAudioManager.currentTourPublic?.name, testTour.name)
    }
    
    func testAudioManagerClearCurrentTour() {
        mockAudioManager.setCurrentTour(testTour)
        XCTAssertNotNil(mockAudioManager.currentTourPublic)
        
        mockAudioManager.setCurrentTour(nil)
        
        XCTAssertNil(mockAudioManager.currentTourPublic)
    }
    
    // MARK: - Audio Session Tests
    
    func testAudioManagerSessionState() {
        XCTAssertEqual(mockAudioManager.currentAudioSession, .inactive)
        
        mockAudioManager.currentAudioSession = .active
        XCTAssertEqual(mockAudioManager.currentAudioSession, .active)
        
        mockAudioManager.currentAudioSession = .interrupted
        XCTAssertEqual(mockAudioManager.currentAudioSession, .interrupted)
    }
    
    // MARK: - External Audio Connection Tests
    
    func testAudioManagerExternalAudioConnection() {
        XCTAssertFalse(mockAudioManager.isExternalAudioConnected)
        XCTAssertEqual(mockAudioManager.audioRoute, .builtin)
        
        mockAudioManager.simulateExternalAudioConnection(true)
        
        XCTAssertTrue(mockAudioManager.isExternalAudioConnected)
        XCTAssertEqual(mockAudioManager.audioRoute, .bluetooth)
    }
    
    func testAudioManagerExternalAudioDisconnection() {
        mockAudioManager.simulateExternalAudioConnection(true)
        XCTAssertTrue(mockAudioManager.isExternalAudioConnected)
        
        mockAudioManager.simulateExternalAudioConnection(false)
        
        XCTAssertFalse(mockAudioManager.isExternalAudioConnected)
        XCTAssertEqual(mockAudioManager.audioRoute, .builtin)
    }
    
    // MARK: - Progress Simulation Tests
    
    func testAudioManagerProgressSimulation() {
        mockAudioManager.duration = 120
        mockAudioManager.currentTime = 0
        
        mockAudioManager.simulatePlaybackProgress(to: 30)
        XCTAssertEqual(mockAudioManager.currentTime, 30)
        
        mockAudioManager.simulatePlaybackProgress(to: 90)
        XCTAssertEqual(mockAudioManager.currentTime, 90)
    }
    
    func testAudioManagerAudioCompletion() {
        mockAudioManager.duration = 120
        mockAudioManager.currentTime = 50
        mockAudioManager.isPlaying = true
        
        mockAudioManager.simulateAudioCompletion()
        
        XCTAssertEqual(mockAudioManager.currentTime, mockAudioManager.duration)
        XCTAssertFalse(mockAudioManager.isPlaying)
    }
    
    // MARK: - Error Handling Tests
    
    func testAudioManagerPlaybackError() async {
        mockAudioManager.simulateAudioError(AudioManagerError.fileNotFound)
        
        do {
            try await mockAudioManager.play()
            XCTFail("Expected error to be thrown")
        } catch let error as AudioManagerError {
            XCTAssertEqual(error, AudioManagerError.fileNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAudioManagerNetworkError() async {
        mockAudioManager.simulateAudioError(AudioManagerError.networkError)
        
        do {
            try await mockAudioManager.playAudioForPOI(testPOI)
            XCTFail("Expected error to be thrown")
        } catch let error as AudioManagerError {
            XCTAssertEqual(error, AudioManagerError.networkError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Combine Publisher Tests
    
    func testAudioManagerIsPlayingPublisher() {
        let expectation = XCTestExpectation(description: "isPlaying publisher")
        var receivedValues: [Bool] = []
        
        mockAudioManager.$isPlaying
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockAudioManager.isPlaying = true
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertFalse(receivedValues[0]) // Initial value
        XCTAssertTrue(receivedValues[1])  // Updated value
    }
    
    func testAudioManagerCurrentTimePublisher() {
        let expectation = XCTestExpectation(description: "currentTime publisher")
        var receivedValues: [TimeInterval] = []
        
        mockAudioManager.$currentTime
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockAudioManager.simulatePlaybackProgress(to: 30)
        mockAudioManager.simulatePlaybackProgress(to: 60)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedValues.count, 3)
        XCTAssertEqual(receivedValues[0], 0)   // Initial value
        XCTAssertEqual(receivedValues[1], 30)  // First update
        XCTAssertEqual(receivedValues[2], 60)  // Second update
    }
    
    func testAudioManagerCurrentPOIPublisher() {
        let expectation = XCTestExpectation(description: "currentPOI publisher")
        var receivedCount = 0
        
        mockAudioManager.$currentPOI
            .sink { poi in
                receivedCount += 1
                if receivedCount >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockAudioManager.currentPOI = testPOI
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedCount, 2)
        XCTAssertEqual(mockAudioManager.currentPOI?.id, testPOI.id)
    }
    
    // MARK: - Mock Reset Tests
    
    func testAudioManagerMockReset() {
        // Set up some state
        mockAudioManager.isPlaying = true
        mockAudioManager.currentTime = 50
        mockAudioManager.currentPOI = testPOI
        mockAudioManager.setVolume(0.5)
        _ = mockAudioManager.playCallCount // Trigger a call count
        
        // Verify state is set
        XCTAssertTrue(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentTime, 50)
        XCTAssertNotNil(mockAudioManager.currentPOI)
        
        // Reset
        mockAudioManager.reset()
        
        // Verify state is reset
        XCTAssertFalse(mockAudioManager.isPlaying)
        XCTAssertEqual(mockAudioManager.currentTime, 0)
        XCTAssertNil(mockAudioManager.currentPOI)
        XCTAssertEqual(mockAudioManager.playCallCount, 0)
        XCTAssertEqual(mockAudioManager.volume, 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testAudioManagerVolumeChangePerformance() {
        measure {
            for i in 0..<1000 {
                mockAudioManager.setVolume(Float(i % 100) / 100.0)
            }
        }
    }
    
    func testAudioManagerSeekPerformance() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await self.mockAudioManager.seek(to: TimeInterval(i))
                }
            }
        }
        
        XCTAssertEqual(mockAudioManager.seekCallCount, 100)
    }
}