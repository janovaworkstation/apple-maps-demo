import Foundation
import AVFoundation
import UIKit

// MARK: - AudioBufferManager

@MainActor
final class AudioBufferManager: ObservableObject {
    
    // MARK: - Configuration
    private let deviceCapability: DeviceCapability
    private let memoryPressureMonitor: MemoryPressureMonitor
    
    // MARK: - Buffer Settings
    @Published private(set) var currentBufferConfig: AudioBufferConfiguration
    @Published private(set) var bufferStatistics = AudioBufferStatistics()
    
    // MARK: - State
    private var tourType: TourType = .mixed
    private var isBackgroundMode = false
    private var connectionQuality: AudioConnectionQuality = .good
    
    // MARK: - Initialization
    
    init() {
        self.deviceCapability = DeviceCapability.current
        self.memoryPressureMonitor = MemoryPressureMonitor()
        self.currentBufferConfig = AudioBufferConfiguration.defaultConfiguration(for: deviceCapability)
        
        setupMemoryPressureObserving()
        print("🔊 AudioBufferManager initialized for \(deviceCapability.tier) device")
    }
    
    deinit {
        memoryPressureMonitor.stop()
        print("🧹 AudioBufferManager cleanup completed")
    }
    
    // MARK: - Public Interface
    
    /// Configure buffer settings for a specific tour type
    func configureBifers(for tourType: TourType) {
        self.tourType = tourType
        updateBufferConfiguration()
        print("🔊 Buffer configured for \(tourType) tour")
    }
    
    /// Adjust buffer settings based on current playing state
    func adjustBuffersForPlayback(
        isPlaying: Bool,
        isCrossfading: Bool,
        isBackgroundMode: Bool
    ) {
        self.isBackgroundMode = isBackgroundMode
        
        let targetConfig = calculateOptimalBufferConfig(
            tourType: tourType,
            isPlaying: isPlaying,
            isCrossfading: isCrossfading,
            isBackground: isBackgroundMode,
            connectionQuality: connectionQuality
        )
        
        if targetConfig != currentBufferConfig {
            currentBufferConfig = targetConfig
            print("🔊 Buffer adjusted: \(targetConfig.description)")
        }
    }
    
    /// Update connection quality to optimize buffer sizes
    func updateConnectionQuality(_ quality: AudioConnectionQuality) {
        self.connectionQuality = quality
        updateBufferConfiguration()
    }
    
    /// Get optimal buffer size for AVAudioPlayer
    func getOptimalBufferSize() -> Int {
        return currentBufferConfig.audioPlayerBufferSize
    }
    
    /// Get optimal queue size for crossfading
    func getOptimalQueueSize() -> Int {
        return currentBufferConfig.crossfadeQueueSize
    }
    
    /// Get optimal preload buffer count
    func getOptimalPreloadCount() -> Int {
        return currentBufferConfig.preloadBufferCount
    }
    
    /// Record buffer performance metrics
    func recordBufferMetrics(
        underruns: Int,
        latency: TimeInterval,
        memoryUsage: Int64
    ) {
        bufferStatistics.totalUnderruns += underruns
        bufferStatistics.averageLatency = (bufferStatistics.averageLatency + latency) / 2.0
        bufferStatistics.currentMemoryUsage = memoryUsage
        bufferStatistics.lastUpdated = Date()
        
        // Adjust configuration if performance is poor
        if underruns > 0 {
            adaptToUnderperformance()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryPressureObserving() {
        memoryPressureMonitor.onMemoryPressure = { [weak self] level in
            Task { @MainActor in
                await self?.handleMemoryPressure(level)
            }
        }
        memoryPressureMonitor.start()
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) async {
        print("⚠️ Memory pressure detected: \(level)")
        
        switch level {
        case .warning:
            // Reduce buffer sizes moderately
            currentBufferConfig = currentBufferConfig.reducedMemoryVersion()
        case .critical:
            // Use minimal buffer sizes
            currentBufferConfig = AudioBufferConfiguration.minimalConfiguration()
        }
        
        bufferStatistics.memoryPressureEvents += 1
        print("🔊 Buffer configuration adjusted for memory pressure")
    }
    
    private func updateBufferConfiguration() {
        let newConfig = calculateOptimalBufferConfig(
            tourType: tourType,
            isPlaying: false,
            isCrossfading: false,
            isBackground: isBackgroundMode,
            connectionQuality: connectionQuality
        )
        
        currentBufferConfig = newConfig
    }
    
    private func calculateOptimalBufferConfig(
        tourType: TourType,
        isPlaying: Bool,
        isCrossfading: Bool,
        isBackground: Bool,
        connectionQuality: AudioConnectionQuality
    ) -> AudioBufferConfiguration {
        
        var baseConfig = AudioBufferConfiguration.defaultConfiguration(for: deviceCapability)
        
        // Adjust for tour type
        switch tourType {
        case .driving:
            // Larger buffers for driving to handle GPS signal loss
            baseConfig = baseConfig.scaledVersion(factor: 1.5)
        case .walking:
            // Standard buffers for walking
            baseConfig = baseConfig.scaledVersion(factor: 1.0)
        case .mixed:
            // Moderate increase for mixed tours
            baseConfig = baseConfig.scaledVersion(factor: 1.2)
        @unknown default:
            break
        }
        
        // Adjust for connection quality
        switch connectionQuality {
        case .poor:
            baseConfig = baseConfig.scaledVersion(factor: 1.8) // Much larger buffers
        case .good:
            baseConfig = baseConfig.scaledVersion(factor: 1.0)
        case .excellent:
            baseConfig = baseConfig.scaledVersion(factor: 0.8) // Smaller buffers
        }
        
        // Adjust for background mode
        if isBackground {
            baseConfig = baseConfig.backgroundModeVersion()
        }
        
        // Adjust for crossfading
        if isCrossfading {
            baseConfig = baseConfig.crossfadeVersion()
        }
        
        // Apply device-specific constraints
        return baseConfig.constrainedToDevice(deviceCapability)
    }
    
    private func adaptToUnderperformance() {
        // Increase buffer sizes to prevent future underruns
        currentBufferConfig = currentBufferConfig.scaledVersion(factor: 1.3)
        bufferStatistics.adaptationCount += 1
        print("🔊 Buffer sizes increased due to underperformance")
    }
}

// MARK: - Supporting Types

struct AudioBufferConfiguration: Equatable {
    let audioPlayerBufferSize: Int      // Bytes
    let crossfadeQueueSize: Int         // Number of buffers
    let preloadBufferCount: Int         // Number of preload buffers
    let maxMemoryUsage: Int64          // Bytes
    
    var description: String {
        return "Player: \(audioPlayerBufferSize/1024)KB, Queue: \(crossfadeQueueSize), Preload: \(preloadBufferCount)"
    }
    
    static func defaultConfiguration(for device: DeviceCapability) -> AudioBufferConfiguration {
        switch device.tier {
        case .low:
            return AudioBufferConfiguration(
                audioPlayerBufferSize: 64 * 1024,    // 64KB
                crossfadeQueueSize: 2,                // 2 buffers
                preloadBufferCount: 1,                // 1 preload buffer
                maxMemoryUsage: 10 * 1024 * 1024     // 10MB
            )
        case .medium:
            return AudioBufferConfiguration(
                audioPlayerBufferSize: 128 * 1024,   // 128KB
                crossfadeQueueSize: 3,                // 3 buffers
                preloadBufferCount: 2,                // 2 preload buffers
                maxMemoryUsage: 25 * 1024 * 1024     // 25MB
            )
        case .high:
            return AudioBufferConfiguration(
                audioPlayerBufferSize: 256 * 1024,   // 256KB
                crossfadeQueueSize: 4,                // 4 buffers
                preloadBufferCount: 3,                // 3 preload buffers
                maxMemoryUsage: 50 * 1024 * 1024     // 50MB
            )
        }
    }
    
    static func minimalConfiguration() -> AudioBufferConfiguration {
        return AudioBufferConfiguration(
            audioPlayerBufferSize: 32 * 1024,        // 32KB
            crossfadeQueueSize: 1,                    // 1 buffer
            preloadBufferCount: 0,                    // No preload
            maxMemoryUsage: 5 * 1024 * 1024          // 5MB
        )
    }
    
    func scaledVersion(factor: Double) -> AudioBufferConfiguration {
        return AudioBufferConfiguration(
            audioPlayerBufferSize: Int(Double(audioPlayerBufferSize) * factor),
            crossfadeQueueSize: max(1, Int(Double(crossfadeQueueSize) * factor)),
            preloadBufferCount: max(0, Int(Double(preloadBufferCount) * factor)),
            maxMemoryUsage: Int64(Double(maxMemoryUsage) * factor)
        )
    }
    
    func reducedMemoryVersion() -> AudioBufferConfiguration {
        return AudioBufferConfiguration(
            audioPlayerBufferSize: audioPlayerBufferSize / 2,
            crossfadeQueueSize: max(1, crossfadeQueueSize - 1),
            preloadBufferCount: max(0, preloadBufferCount - 1),
            maxMemoryUsage: maxMemoryUsage / 2
        )
    }
    
    func backgroundModeVersion() -> AudioBufferConfiguration {
        return AudioBufferConfiguration(
            audioPlayerBufferSize: audioPlayerBufferSize * 2,  // Larger buffers for background
            crossfadeQueueSize: crossfadeQueueSize,
            preloadBufferCount: max(0, preloadBufferCount - 1), // Reduce preload in background
            maxMemoryUsage: maxMemoryUsage
        )
    }
    
    func crossfadeVersion() -> AudioBufferConfiguration {
        return AudioBufferConfiguration(
            audioPlayerBufferSize: audioPlayerBufferSize,
            crossfadeQueueSize: crossfadeQueueSize + 1,         // Extra buffer for crossfading
            preloadBufferCount: preloadBufferCount,
            maxMemoryUsage: maxMemoryUsage + (1024 * 1024)     // Extra 1MB for crossfade
        )
    }
    
    func constrainedToDevice(_ device: DeviceCapability) -> AudioBufferConfiguration {
        let maxAllowedMemory = device.availableMemoryMB * 1024 * 1024 / 10  // Use max 10% of available memory
        
        return AudioBufferConfiguration(
            audioPlayerBufferSize: min(audioPlayerBufferSize, device.maxBufferSize),
            crossfadeQueueSize: min(crossfadeQueueSize, device.maxQueueSize),
            preloadBufferCount: min(preloadBufferCount, device.maxPreloadBuffers),
            maxMemoryUsage: min(maxMemoryUsage, Int64(maxAllowedMemory))
        )
    }
}

struct AudioBufferStatistics {
    var totalUnderruns: Int = 0
    var averageLatency: TimeInterval = 0.0
    var currentMemoryUsage: Int64 = 0
    var memoryPressureEvents: Int = 0
    var adaptationCount: Int = 0
    var lastUpdated: Date = Date()
    
    var formattedMemoryUsage: String {
        ByteCountFormatter().string(fromByteCount: currentMemoryUsage)
    }
}

enum AudioConnectionQuality {
    case poor, good, excellent
}

// MARK: - Device Capability Detection

struct DeviceCapability {
    let tier: DeviceTier
    let availableMemoryMB: Int
    let maxBufferSize: Int
    let maxQueueSize: Int
    let maxPreloadBuffers: Int
    
    static var current: DeviceCapability {
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        let availableMemoryMB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        
        let tier: DeviceTier
        let maxBufferSize: Int
        let maxQueueSize: Int
        let maxPreloadBuffers: Int
        
        if memoryGB >= 6 {
            tier = .high
            maxBufferSize = 512 * 1024  // 512KB
            maxQueueSize = 6
            maxPreloadBuffers = 4
        } else if memoryGB >= 3 {
            tier = .medium
            maxBufferSize = 256 * 1024  // 256KB
            maxQueueSize = 4
            maxPreloadBuffers = 2
        } else {
            tier = .low
            maxBufferSize = 128 * 1024  // 128KB
            maxQueueSize = 2
            maxPreloadBuffers = 1
        }
        
        return DeviceCapability(
            tier: tier,
            availableMemoryMB: availableMemoryMB,
            maxBufferSize: maxBufferSize,
            maxQueueSize: maxQueueSize,
            maxPreloadBuffers: maxPreloadBuffers
        )
    }
}

enum DeviceTier {
    case low, medium, high
}

// MARK: - Memory Pressure Monitor

class MemoryPressureMonitor {
    private var pressureSource: DispatchSourceMemoryPressure?
    var onMemoryPressure: ((MemoryPressureLevel) -> Void)?
    
    func start() {
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.main
        )
        
        pressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.pressureSource?.mask
            if event?.contains(.critical) == true {
                self.onMemoryPressure?(.critical)
            } else if event?.contains(.warning) == true {
                self.onMemoryPressure?(.warning)
            }
        }
        
        pressureSource?.resume()
    }
    
    func stop() {
        pressureSource?.cancel()
        pressureSource = nil
    }
}

enum MemoryPressureLevel {
    case warning, critical
}