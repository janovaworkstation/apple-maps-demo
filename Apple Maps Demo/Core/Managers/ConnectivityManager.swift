import Foundation
import Combine
import Network

// MARK: - ConnectivityManager

@MainActor
class ConnectivityManager: ObservableObject {
    static let shared = ConnectivityManager()
    
    // MARK: - Published Properties
    @Published var networkStatus: NetworkStatus = .none
    @Published var connectionQuality: ConnectionQuality = .poor
    @Published var isOnline: Bool = false
    @Published var isHighQualityConnection: Bool = false
    
    // MARK: - Private Properties
    private var networkMonitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private var qualityTestTimer: Timer?
    private var lastQualityCheck: Date = Date()
    private var connectivityHistory: [ConnectionQuality] = []
    private let maxHistorySize = 10
    
    // Hysteresis thresholds to prevent flapping
    private let switchingThresholds = ConnectivityThresholds()
    private var lastSwitchTime: Date = Date()
    private let minimumSwitchInterval: TimeInterval = 5.0 // Prevent rapid switching
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupNetworkMonitoring()
        startQualityMonitoring()
        print("📡 ConnectivityManager initialized")
    }
    
    deinit {
        // Stop monitoring synchronously to avoid capture issues
        networkMonitor?.cancel()
        qualityTestTimer?.invalidate()
        qualityTestTimer = nil
    }
    
    // MARK: - Public Interface
    
    /// Get current connection quality with caching
    func getCurrentConnectionQuality() -> ConnectionQuality {
        return connectionQuality
    }
    
    /// Force a connection quality test
    func testConnectionQuality() async -> ConnectionQuality {
        return await performQualityTest()
    }
    
    /// Check if network is suitable for live LLM requests
    func isNetworkSuitableForLLM() -> Bool {
        return isOnline && 
               (connectionQuality == .excellent || connectionQuality == .good) &&
               networkStatus != .cellular // Prefer WiFi for LLM requests
    }
    
    /// Check if network is suitable for downloading audio content
    func isNetworkSuitableForDownload() -> Bool {
        return isOnline && connectionQuality != .poor
    }
    
    /// Get optimal timeout for network requests based on connection quality
    func getOptimalTimeout() -> TimeInterval {
        switch connectionQuality {
        case .excellent: return 10.0
        case .good: return 15.0
        case .fair: return 25.0
        case .poor: return 45.0
        }
    }
    
    /// Get retry count for network requests based on connection quality
    func getOptimalRetryCount() -> Int {
        switch connectionQuality {
        case .excellent, .good: return 2
        case .fair: return 3
        case .poor: return 1
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        setupPathMonitor()
    }
    
    private func setupPathMonitor() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.handlePathUpdate(path)
            }
        }
        
        networkMonitor?.start(queue: monitorQueue)
        print("✅ Network path monitoring started")
    }
    
    private func handlePathUpdate(_ path: NWPath) async {
        let previousStatus = networkStatus
        let isCurrentlyOnline = path.status == .satisfied
        
        // Determine network type from path
        if isCurrentlyOnline {
            if path.usesInterfaceType(.wifi) {
                networkStatus = .wifi
            } else if path.usesInterfaceType(.cellular) {
                networkStatus = .cellular
            } else {
                networkStatus = .wifi // Default for other types (ethernet, etc.)
            }
        } else {
            networkStatus = .none
        }
        
        isOnline = isCurrentlyOnline
        
        if previousStatus != networkStatus {
            await handleConnectivityChange(from: previousStatus, to: networkStatus)
        }
        
        if !isOnline {
            connectionQuality = .poor
            await broadcastConnectivityChange()
        }
    }
    
    private func handleNetworkUnavailable() async {
        networkStatus = .none
        isOnline = false
        connectionQuality = .poor
        isHighQualityConnection = false
        await broadcastConnectivityChange()
    }
    
    private func handleConnectivityChange(from previous: NetworkStatus, to current: NetworkStatus) async {
        print("📡 Network status changed: \(previous) → \(current)")
        
        // Apply hysteresis to prevent flapping
        guard Date().timeIntervalSince(lastSwitchTime) > minimumSwitchInterval else {
            print("⏳ Connectivity change ignored (too soon after last switch)")
            return
        }
        
        lastSwitchTime = Date()
        
        // Update connection quality when network changes
        if isOnline {
            let newQuality = await performQualityTest()
            connectionQuality = newQuality
            isHighQualityConnection = (newQuality == .excellent || newQuality == .good)
        }
        
        await broadcastConnectivityChange()
    }
    
    private func broadcastConnectivityChange() async {
        // Post notification for other components
        NotificationCenter.default.post(
            name: Notification.Name(Constants.Notifications.connectivityChanged),
            object: ConnectivityInfo(
                status: networkStatus,
                quality: connectionQuality,
                isOnline: isOnline
            )
        )
        
        print("📡 Connectivity change broadcasted: \(networkStatus), Quality: \(connectionQuality)")
    }
    
    // MARK: - Quality Monitoring
    
    private func startQualityMonitoring() {
        qualityTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicQualityCheck()
            }
        }
    }
    
    private func performPeriodicQualityCheck() async {
        guard isOnline else { return }
        
        let newQuality = await performQualityTest()
        
        if shouldUpdateQuality(from: connectionQuality, to: newQuality) {
            connectionQuality = newQuality
            isHighQualityConnection = (newQuality == .excellent || newQuality == .good)
            
            // Only broadcast if quality changed significantly
            if abs(connectionQuality.rawValue - newQuality.rawValue) >= 2 {
                await broadcastConnectivityChange()
            }
        }
        
        // Update history
        addQualityToHistory(newQuality)
    }
    
    private func performQualityTest() async -> ConnectionQuality {
        guard isOnline else { return .poor }
        
        let startTime = Date()
        let testURL = URL(string: "https://httpbin.org/delay/0")!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: testURL)
            let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .poor
            }
            
            return classifyConnectionQuality(latency: latency)
        } catch {
            print("📡 Quality test failed: \(error)")
            return .poor
        }
    }
    
    private func classifyConnectionQuality(latency: TimeInterval) -> ConnectionQuality {
        switch networkStatus {
        case .wifi:
            switch latency {
            case 0..<100: return .excellent
            case 100..<300: return .good
            case 300..<1000: return .fair
            default: return .poor
            }
        case .cellular:
            switch latency {
            case 0..<200: return .excellent
            case 200..<500: return .good
            case 500..<1500: return .fair
            default: return .poor
            }
        case .none:
            return .poor
        }
    }
    
    private func shouldUpdateQuality(from current: ConnectionQuality, to new: ConnectionQuality) -> Bool {
        // Apply hysteresis based on thresholds
        let currentValue = current.rawValue
        let newValue = new.rawValue
        
        if newValue > currentValue {
            // Upgrading quality - require crossing upper threshold
            return newValue >= switchingThresholds.upperThreshold(for: current)
        } else if newValue < currentValue {
            // Downgrading quality - require crossing lower threshold
            return newValue <= switchingThresholds.lowerThreshold(for: current)
        }
        
        return false
    }
    
    private func addQualityToHistory(_ quality: ConnectionQuality) {
        connectivityHistory.append(quality)
        if connectivityHistory.count > maxHistorySize {
            connectivityHistory.removeFirst()
        }
    }
    
    func getQualityTrend() -> QualityTrend {
        guard connectivityHistory.count >= 3 else { return .stable }
        
        let recent = Array(connectivityHistory.suffix(3))
        let avgRecent = recent.map { $0.rawValue }.reduce(0, +) / recent.count
        let avgOlder = connectivityHistory.dropLast(3).map { $0.rawValue }.reduce(0, +) / max(1, connectivityHistory.count - 3)
        
        if avgRecent > avgOlder + 1 { return .improving }
        if avgRecent < avgOlder - 1 { return .degrading }
        return .stable
    }
    
    private func stopMonitoring() {
        networkMonitor?.cancel()
        qualityTestTimer?.invalidate()
        qualityTestTimer = nil
    }
}

// MARK: - Supporting Types

enum NetworkStatus: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case none = "No Connection"
    
    var description: String { rawValue }
}

enum ConnectionQuality: Int, CaseIterable {
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
    
    var icon: String {
        switch self {
        case .poor: return "wifi.slash"
        case .fair: return "wifi.exclamationmark"
        case .good: return "wifi"
        case .excellent: return "wifi.circle.fill"
        }
    }
}

enum QualityTrend {
    case improving
    case stable
    case degrading
}

struct ConnectivityInfo {
    let status: NetworkStatus
    let quality: ConnectionQuality
    let isOnline: Bool
    let timestamp: Date = Date()
}

struct ConnectivityThresholds {
    func upperThreshold(for quality: ConnectionQuality) -> Int {
        switch quality {
        case .poor: return 3 // Must reach good to upgrade from poor
        case .fair: return 4 // Must reach excellent to upgrade from fair
        case .good: return 4 // Already good, must reach excellent
        case .excellent: return 4 // Already at max
        }
    }
    
    func lowerThreshold(for quality: ConnectionQuality) -> Int {
        switch quality {
        case .poor: return 1 // Already at min
        case .fair: return 1 // Must drop to poor to downgrade from fair
        case .good: return 2 // Must drop to fair to downgrade from good
        case .excellent: return 2 // Must drop to fair to downgrade from excellent
        }
    }
}