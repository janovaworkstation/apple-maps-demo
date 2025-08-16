//
//  MockAudioManager.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import Foundation
import Combine
import CoreLocation
@testable import Apple_Maps_Demo

enum AudioManagerError: Error {
    case fileNotFound
    case invalidFormat
    case playbackFailed
    case networkError
    case permissionDenied
}

@MainActor
final class MockAudioManager: ObservableObject {
    
    // MARK: - Published Properties (Mirror AudioManager)
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentPOI: PointOfInterest?
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 1.0
    @Published var isCrossfading = false
    @Published var isBuffering = false
    @Published var audioQuality: AudioQuality = .medium
    @Published var connectionStatus: AudioConnectionStatus = .builtin
    @Published var isAutoPlayEnabled = true
    @Published var currentPlaybackSession: AudioPlaybackSession?
    @Published var playbackHistory: [AudioPlaybackRecord] = []
    @Published var audioRoute: AudioRoute = .builtin
    @Published var isExternalAudioConnected = false
    @Published var currentAudioSession: AudioSessionState = .inactive
    @Published var currentTourPublic: Tour?
    
    // MARK: - Mock State
    var playCallCount = 0
    var pauseCallCount = 0
    var stopCallCount = 0
    var seekCallCount = 0
    var setVolumeCallCount = 0
    var setPlaybackRateCallCount = 0
    
    var lastSeekTime: TimeInterval?
    var lastVolumeValue: Float?
    var lastPlaybackRateValue: Float?
    
    var shouldFailPlayback = false
    var playbackError: Error?
    
    // MARK: - Mock Implementation
    
    func play() async throws {
        playCallCount += 1
        
        if shouldFailPlayback {
            if let error = playbackError {
                throw error
            } else {
                throw AudioManagerError.playbackFailed
            }
        }
        
        isPlaying = true
        currentAudioSession = .active
    }
    
    func pause() {
        pauseCallCount += 1
        isPlaying = false
    }
    
    func stop() {
        stopCallCount += 1
        isPlaying = false
        currentTime = 0
        currentPOI = nil
        currentAudioSession = .inactive
    }
    
    func seek(to time: TimeInterval) async {
        seekCallCount += 1
        lastSeekTime = time
        currentTime = time
    }
    
    func seekToTime(_ time: TimeInterval) async {
        await seek(to: time)
    }
    
    func setVolume(_ volume: Float) {
        setVolumeCallCount += 1
        lastVolumeValue = volume
        self.volume = volume
    }
    
    func setPlaybackRate(_ rate: Float) {
        setPlaybackRateCallCount += 1
        lastPlaybackRateValue = rate
        self.playbackRate = rate
    }
    
    func playAudioForPOI(_ poi: PointOfInterest) async throws {
        currentPOI = poi
        duration = poi.audioContent.duration
        try await play()
    }
    
    func togglePlayback() async {
        if isPlaying {
            pause()
        } else {
            try? await play()
        }
    }
    
    func skipForward(_ seconds: TimeInterval = 30) async {
        let newTime = min(currentTime + seconds, duration)
        await seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval = 30) async {
        let newTime = max(currentTime - seconds, 0)
        await seek(to: newTime)
    }
    
    func setCurrentTour(_ tour: Tour?) {
        currentTourPublic = tour
    }
    
    // MARK: - Mock Helpers
    
    func simulatePlaybackProgress(to time: TimeInterval) {
        currentTime = time
    }
    
    func simulateAudioCompletion() {
        currentTime = duration
        isPlaying = false
    }
    
    func simulateAudioError(_ error: Error) {
        playbackError = error
        shouldFailPlayback = true
    }
    
    func simulateExternalAudioConnection(_ connected: Bool) {
        isExternalAudioConnected = connected
        audioRoute = connected ? .bluetooth : .builtin
    }
    
    func reset() {
        playCallCount = 0
        pauseCallCount = 0
        stopCallCount = 0
        seekCallCount = 0
        setVolumeCallCount = 0
        setPlaybackRateCallCount = 0
        
        lastSeekTime = nil
        lastVolumeValue = nil
        lastPlaybackRateValue = nil
        
        shouldFailPlayback = false
        playbackError = nil
        
        isPlaying = false
        currentTime = 0
        duration = 0
        currentPOI = nil
        volume = 1.0
        playbackRate = 1.0
        currentTourPublic = nil
    }
}

// MARK: - Supporting Types

enum AudioRoute {
    case builtin
    case bluetooth
    case headphones
    case speaker
}

enum AudioConnectionStatus {
    case builtin
    case bluetooth
    case wired
}

enum AudioSessionState: Equatable {
    case inactive
    case active
    case interrupted
}

struct AudioPlaybackSession {
    let id: UUID
    let startTime: Date
    let poi: PointOfInterest
}

struct AudioPlaybackRecord {
    let id: UUID
    let poi: PointOfInterest
    let playedAt: Date
    let duration: TimeInterval
}