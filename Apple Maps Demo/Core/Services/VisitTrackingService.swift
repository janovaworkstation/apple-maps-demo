import Foundation
import CoreLocation
import Combine

// MARK: - VisitTrackingService Protocol

@MainActor
protocol VisitTrackingServiceProtocol {
    // Visit Management
    func startVisitSession(for poi: PointOfInterest, userLocation: CLLocation) async throws
    func endVisitSession(for poi: PointOfInterest) async throws
    func validateVisit(for poi: PointOfInterest, userLocation: CLLocation) async -> VisitValidationResult
    
    // Session Monitoring
    func getCurrentVisitSession() -> VisitSession?
    func getVisitHistory(for tourId: UUID?) async throws -> [CompletedVisit]
    
    // Analytics
    func getVisitStatistics(for tourId: UUID?) async throws -> VisitStatistics
    func getTourProgress(for tourId: UUID) async throws -> TourProgressData
    
    // Publishers
    var visitEvents: AnyPublisher<VisitEvent, Never> { get }
    var sessionUpdates: AnyPublisher<VisitSessionUpdate, Never> { get }
}

// MARK: - VisitTrackingService Implementation

@MainActor
class VisitTrackingService: VisitTrackingServiceProtocol, ObservableObject {
    static let shared = VisitTrackingService()
    
    // MARK: - Dependencies
    private let dataService: DataService
    private let locationManager: LocationManager
    
    // MARK: - State
    @Published private(set) var currentVisitSession: VisitSession?
    @Published private(set) var visitValidationCandidates: [VisitCandidate] = []
    @Published private(set) var currentUserSpeed: Double = 0.0 // mph
    @Published private(set) var averageApproachSpeed: Double = 0.0 // mph
    private var speedHistory: [SpeedReading] = [] // Last 10 speed readings
    private var locationHistory: [CLLocation] = [] // Last 5 location readings for trajectory
    @Published private(set) var currentHeading: CLLocationDirection? // Current direction of travel
    
    // MARK: - Publishers
    private let visitEventsSubject = PassthroughSubject<VisitEvent, Never>()
    private let sessionUpdatesSubject = PassthroughSubject<VisitSessionUpdate, Never>()
    
    var visitEvents: AnyPublisher<VisitEvent, Never> {
        visitEventsSubject.eraseToAnyPublisher()
    }
    
    var sessionUpdates: AnyPublisher<VisitSessionUpdate, Never> {
        sessionUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Configuration (Dynamic based on tour type)
    private let maxAccuracyThreshold: CLLocationAccuracy = 25 // 25 meters default (tour type can override)
    private let visitRadiusMultiplier: Double = 0.8 // 80% of POI radius for stricter validation
    private var currentTour: Tour? // Track current tour for dynamic configuration
    
    private var cancellables = Set<AnyCancellable>()
    private var validationTimer: Timer?
    
    // MARK: - Dynamic Configuration Properties
    
    private var effectiveDwellTime: TimeInterval {
        return currentTour?.effectiveDwellTime ?? 30.0 // Default to 30 seconds
    }
    
    private var effectiveValidationInterval: TimeInterval {
        return currentTour?.tourType.validationInterval ?? 5.0 // Default to 5 seconds
    }
    
    private var effectiveAccuracyThreshold: CLLocationAccuracy {
        return currentTour?.tourType.requiredGPSAccuracy ?? maxAccuracyThreshold
    }
    
    private var supportsDriveByVisits: Bool {
        return currentTour?.tourType.supportsDriveByVisits ?? false
    }
    
    private var currentTourMaxSpeed: Double {
        return currentTour?.effectiveMaxSpeed ?? 45.0 // Default to 45 mph
    }
    
    private var isMovingAtDrivingSpeed: Bool {
        return currentUserSpeed >= 15.0 // 15+ mph considered driving
    }
    
    private var isMovingAtWalkingSpeed: Bool {
        return currentUserSpeed <= 8.0 // 8 mph or less considered walking
    }
    
    // MARK: - Initialization
    
    private init(
        dataService: DataService? = nil,
        locationManager: LocationManager? = nil
    ) {
        self.dataService = dataService ?? MainActor.assumeIsolated { DataService.shared }
        self.locationManager = locationManager ?? LocationManager.shared
        
        setupLocationMonitoring()
    }
    
    private func setupLocationMonitoring() {
        // Monitor location updates for ongoing validation and speed tracking
        locationManager.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.updateLocationData(from: location)
                self?.updateSpeedData(from: location)
                self?.updateTrajectoryData(from: location)
                self?.validateOngoingSessions(with: location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Tour Configuration
    
    func setCurrentTour(_ tour: Tour?) {
        currentTour = tour
        print("📋 Visit tracking configured for tour type: \(tour?.tourType.rawValue ?? "none")")
        print("⏱️ Effective dwell time: \(effectiveDwellTime)s")
        print("📍 GPS accuracy requirement: \(effectiveAccuracyThreshold)m")
        print("🏎️ Supports drive-by visits: \(supportsDriveByVisits)")
    }
    
    // MARK: - Visit Management
    
    func startVisitSession(for poi: PointOfInterest, userLocation: CLLocation) async throws {
        print("🏁 Starting visit session for POI: \(poi.name)")
        
        // End any existing session
        if let existingSession = currentVisitSession {
            try await endVisitSession(for: existingSession.poi)
        }
        
        // Validate initial conditions
        let validation = await validateVisit(for: poi, userLocation: userLocation)
        guard validation.isValid else {
            throw VisitTrackingError.invalidVisitConditions(validation.reason)
        }
        
        // Create new visit session
        let session = VisitSession(
            poi: poi,
            startTime: Date(),
            startLocation: userLocation,
            requiredDwellTime: effectiveDwellTime
        )
        
        currentVisitSession = session
        
        // Start validation timer
        startValidationTimer()
        
        // Notify about session start
        let event = VisitEvent(
            type: .sessionStarted,
            poi: poi,
            session: session,
            timestamp: Date()
        )
        visitEventsSubject.send(event)
        
        sessionUpdatesSubject.send(.started(session: session))
        
        print("✅ Visit session started for \(poi.name)")
    }
    
    func endVisitSession(for poi: PointOfInterest) async throws {
        guard let session = currentVisitSession,
              session.poi.id == poi.id else {
            throw VisitTrackingError.noActiveSession
        }
        
        print("🏁 Ending visit session for POI: \(poi.name)")
        
        // Stop validation timer
        stopValidationTimer()
        
        // Calculate visit completion
        let visitDuration = Date().timeIntervalSince(session.startTime)
        let isValidVisit = visitDuration >= effectiveDwellTime || supportsDriveByVisits
        
        if isValidVisit {
            // Mark POI as visited and save
            try await markPOIAsVisited(poi, session: session)
            
            // Create completed visit record
            let completedVisit = CompletedVisit(
                id: UUID(),
                poiId: poi.id,
                tourId: poi.tourId,
                startTime: session.startTime,
                endTime: Date(),
                duration: visitDuration,
                startLocation: session.startLocation,
                endLocation: locationManager.currentLocation,
                wasAudioPlayed: false // Will be updated by AudioManager
            )
            
            // Save visit record (could be expanded to save to separate VisitHistory entity)
            print("✅ Valid visit completed: \(visitDuration)s duration")
            
            // Notify about successful visit
            let event = VisitEvent(
                type: .visitCompleted,
                poi: poi,
                session: session,
                timestamp: Date(),
                completedVisit: completedVisit
            )
            visitEventsSubject.send(event)
            
        } else {
            print("❌ Visit session too short: \(visitDuration)s < \(effectiveDwellTime)s required")
            
            // Notify about cancelled visit
            let event = VisitEvent(
                type: .sessionCancelled,
                poi: poi,
                session: session,
                timestamp: Date()
            )
            visitEventsSubject.send(event)
        }
        
        // Clear current session
        currentVisitSession = nil
        sessionUpdatesSubject.send(.ended(wasValid: isValidVisit))
    }
    
    func validateVisit(for poi: PointOfInterest, userLocation: CLLocation) async -> VisitValidationResult {
        // Check location accuracy
        guard userLocation.horizontalAccuracy > 0 && userLocation.horizontalAccuracy <= effectiveAccuracyThreshold else {
            return VisitValidationResult(isValid: false, reason: "GPS accuracy insufficient: \(userLocation.horizontalAccuracy)m")
        }
        
        // Check distance from POI
        let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
        let distance = userLocation.distance(from: poiLocation)
        let requiredRadius = poi.radius * visitRadiusMultiplier
        
        guard distance <= requiredRadius else {
            return VisitValidationResult(isValid: false, reason: "Too far from POI: \(distance)m > \(requiredRadius)m")
        }
        
        // Check if POI is already visited
        if poi.isVisited {
            return VisitValidationResult(isValid: false, reason: "POI already visited")
        }
        
        // Check POI operating hours if available
        if let operatingHours = poi.operatingHours, !operatingHours.isCurrentlyOpen {
            return VisitValidationResult(isValid: false, reason: "POI is currently closed")
        }
        
        // Speed-based validation for driving tours
        if shouldUseSpeedBasedValidation(for: poi, userLocation: userLocation) {
            return validateSpeedBasedVisit(for: poi, userLocation: userLocation)
        }
        
        // Enhanced trajectory-based validation
        if let trajectoryResult = validateTrajectoryBasedVisit(for: poi, userLocation: userLocation) {
            return trajectoryResult
        }
        
        return VisitValidationResult(isValid: true, reason: "All validation criteria met")
    }
    
    // MARK: - Session Monitoring
    
    func getCurrentVisitSession() -> VisitSession? {
        return currentVisitSession
    }
    
    func getVisitHistory(for tourId: UUID?) async throws -> [CompletedVisit] {
        // In a more complete implementation, this would fetch from a dedicated VisitHistory entity
        // For now, we'll derive this from POI visit data
        
        let pois: [PointOfInterest]
        if let tourId = tourId {
            pois = try await dataService.poiRepository.fetchByTour(tourId)
        } else {
            pois = try await dataService.poiRepository.fetchAll()
        }
        
        let visitedPOIs = pois.filter { $0.isVisited }
        
        return visitedPOIs.compactMap { poi in
            guard let visitedAt = poi.visitedAt else { return nil }
            
            return CompletedVisit(
                id: UUID(),
                poiId: poi.id,
                tourId: poi.tourId,
                startTime: visitedAt,
                endTime: visitedAt.addingTimeInterval(poi.dwellTime),
                duration: poi.dwellTime,
                startLocation: CLLocation(latitude: poi.latitude, longitude: poi.longitude),
                endLocation: nil,
                wasAudioPlayed: poi.audioContent != nil
            )
        }.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Analytics
    
    func getVisitStatistics(for tourId: UUID?) async throws -> VisitStatistics {
        let visitHistory = try await getVisitHistory(for: tourId)
        
        let totalVisits = visitHistory.count
        let totalDuration = visitHistory.reduce(0) { $0 + $1.duration }
        let averageDuration = totalVisits > 0 ? totalDuration / Double(totalVisits) : 0
        let audioPlayedCount = visitHistory.filter { $0.wasAudioPlayed }.count
        
        return VisitStatistics(
            totalVisits: totalVisits,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            audioPlayedCount: audioPlayedCount,
            audioPlayedPercentage: totalVisits > 0 ? Double(audioPlayedCount) / Double(totalVisits) * 100 : 0,
            lastVisitDate: visitHistory.last?.startTime
        )
    }
    
    func getTourProgress(for tourId: UUID) async throws -> TourProgressData {
        let allPOIs = try await dataService.poiRepository.fetchByTour(tourId)
        let visitedPOIs = allPOIs.filter { $0.isVisited }
        
        let totalPOIs = allPOIs.count
        let completedPOIs = visitedPOIs.count
        let completionPercentage = totalPOIs > 0 ? Double(completedPOIs) / Double(totalPOIs) * 100 : 0
        
        // Calculate estimated time remaining based on average visit duration
        let stats = try await getVisitStatistics(for: tourId)
        let remainingPOIs = totalPOIs - completedPOIs
        let estimatedTimeRemaining = Double(remainingPOIs) * (stats.averageDuration > 0 ? stats.averageDuration : 120) // Default 2 min per POI
        
        // Calculate total distance (simplified implementation)
        let totalDistance = allPOIs.reduce(0.0) { total, poi in
            return total + 100.0 // Simplified: assume 100m between POIs
        }
        let visitedDistance = totalDistance * (completionPercentage / 100.0)
        
        return TourProgressData(
            tourId: tourId,
            tourName: "Current Tour", // Could be fetched from tour data
            totalPOIs: totalPOIs,
            visitedPOIs: completedPOIs,
            totalDistance: totalDistance,
            visitedDistance: visitedDistance,
            estimatedTimeRemaining: estimatedTimeRemaining,
            completionPercentage: completionPercentage,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Implementation
    
    private func startValidationTimer() {
        stopValidationTimer()
        
        validationTimer = Timer.scheduledTimer(withTimeInterval: effectiveValidationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.validateCurrentSession()
            }
        }
    }
    
    private func stopValidationTimer() {
        validationTimer?.invalidate()
        validationTimer = nil
    }
    
    private func validateCurrentSession() async {
        guard let session = currentVisitSession,
              let userLocation = locationManager.currentLocation else { return }
        
        let validation = await validateVisit(for: session.poi, userLocation: userLocation)
        
        if !validation.isValid {
            print("⚠️ Visit validation failed: \(validation.reason)")
            
            // End session if validation fails
            try? await endVisitSession(for: session.poi)
        } else {
            // Update session progress
            let progress = session.calculateProgress(currentTime: Date())
            sessionUpdatesSubject.send(.progressUpdated(progress: progress))
        }
    }
    
    private func validateOngoingSessions(with location: CLLocation) {
        // This method can be used for additional ongoing validation
        // if we want to continuously monitor without a timer
    }
    
    // MARK: - Location & Trajectory Tracking
    
    private func updateLocationData(from location: CLLocation) {
        // Add to location history (keep last 5 readings)
        locationHistory.append(location)
        
        if locationHistory.count > 5 {
            locationHistory.removeFirst()
        }
    }
    
    private func updateTrajectoryData(from location: CLLocation) {
        // Calculate heading/bearing if we have previous locations
        if locationHistory.count >= 2 {
            let previousLocation = locationHistory[locationHistory.count - 2]
            let bearing = calculateBearing(from: previousLocation, to: location)
            currentHeading = bearing
        }
    }
    
    private func calculateBearing(from startLocation: CLLocation, to endLocation: CLLocation) -> CLLocationDirection {
        let lat1 = startLocation.coordinate.latitude * .pi / 180
        let lat2 = endLocation.coordinate.latitude * .pi / 180
        let deltaLon = (endLocation.coordinate.longitude - startLocation.coordinate.longitude) * .pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(x, y) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - Speed Tracking
    
    private func updateSpeedData(from location: CLLocation) {
        // Convert m/s to mph
        let speedMph = location.speed >= 0 ? location.speed * 2.237 : 0.0
        currentUserSpeed = speedMph
        
        // Add to speed history (keep last 10 readings)
        let speedReading = SpeedReading(speed: speedMph, timestamp: Date(), location: location)
        speedHistory.append(speedReading)
        
        if speedHistory.count > 10 {
            speedHistory.removeFirst()
        }
        
        // Calculate average approach speed
        if speedHistory.count >= 3 {
            let recentSpeeds = speedHistory.suffix(5).map { $0.speed }
            averageApproachSpeed = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
        }
        
        // Log speed changes for debugging
        if abs(speedMph - (speedHistory.dropLast().last?.speed ?? 0)) > 5 {
            print("🏃‍♂️ Speed change: \(String(format: "%.1f", speedMph)) mph (avg: \(String(format: "%.1f", averageApproachSpeed)) mph)")
        }
    }
    
    private func detectTourTypeFromSpeed() -> TourType? {
        guard speedHistory.count >= 3 else { return nil }
        
        let recentSpeeds = speedHistory.suffix(5).map { $0.speed }
        let avgSpeed = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
        
        // Detect tour type based on speed patterns
        if avgSpeed >= 15.0 {
            return .driving
        } else if avgSpeed <= 8.0 {
            return .walking  
        } else {
            return .mixed
        }
    }
    
    private func shouldUseSpeedBasedValidation(for poi: PointOfInterest, userLocation: CLLocation) -> Bool {
        // Use speed-based validation for driving/mixed tours or when moving at driving speed
        return currentTour?.requiresSpeedBasedValidation == true || isMovingAtDrivingSpeed
    }
    
    private func validateSpeedBasedVisit(for poi: PointOfInterest, userLocation: CLLocation) -> VisitValidationResult {
        let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
        let distance = userLocation.distance(from: poiLocation)
        
        // For driving tours, validate based on approach pattern
        if isMovingAtDrivingSpeed {
            // Check if speed is reasonable for the tour
            if currentUserSpeed > currentTourMaxSpeed {
                return VisitValidationResult(
                    isValid: false, 
                    reason: "Speed too high for tour: \(String(format: "%.1f", currentUserSpeed)) mph > \(String(format: "%.1f", currentTourMaxSpeed)) mph limit"
                )
            }
            
            // For driving tours, allow visits even while moving (drive-by visits)
            if supportsDriveByVisits {
                // More lenient distance check for driving
                let drivingRadius = poi.radius * 1.5 // 50% larger radius for driving
                if distance <= drivingRadius {
                    return VisitValidationResult(
                        isValid: true, 
                        reason: "Valid drive-by visit: \(String(format: "%.1f", currentUserSpeed)) mph, \(String(format: "%.0f", distance))m from POI"
                    )
                } else {
                    return VisitValidationResult(
                        isValid: false, 
                        reason: "Too far for drive-by visit: \(String(format: "%.0f", distance))m > \(String(format: "%.0f", drivingRadius))m"
                    )
                }
            }
        }
        
        // For mixed tours or slower speeds, use hybrid validation
        if currentTour?.tourType == .mixed {
            // Adjust requirements based on current speed
            let speedAdjustedRadius = isMovingAtDrivingSpeed ? poi.radius * 1.3 : poi.radius * 0.8
            
            if distance <= speedAdjustedRadius {
                return VisitValidationResult(
                    isValid: true, 
                    reason: "Valid mixed-tour visit: \(String(format: "%.1f", currentUserSpeed)) mph, \(String(format: "%.0f", distance))m from POI"
                )
            } else {
                return VisitValidationResult(
                    isValid: false, 
                    reason: "Distance exceeds speed-adjusted limit: \(String(format: "%.0f", distance))m > \(String(format: "%.0f", speedAdjustedRadius))m"
                )
            }
        }
        
        // Default validation for other cases
        return VisitValidationResult(isValid: true, reason: "Speed-based validation passed")
    }
    
    private func validateTrajectoryBasedVisit(for poi: PointOfInterest, userLocation: CLLocation) -> VisitValidationResult? {
        guard locationHistory.count >= 3 else { return nil } // Need enough data for trajectory analysis
        
        let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
        let currentDistance = userLocation.distance(from: poiLocation)
        
        // Analyze approach pattern
        let approachAnalysis = analyzeApproachPattern(to: poiLocation)
        
        // For driving tours, validate if the user is approaching or has passed the POI
        if currentTour?.tourType == .driving || isMovingAtDrivingSpeed {
            
            // Check if user is moving away from POI (already passed)
            if approachAnalysis.isMovingAway && currentDistance > poi.radius * 1.5 {
                return VisitValidationResult(
                    isValid: false,
                    reason: "User has passed POI while driving (moving away, distance: \(String(format: "%.0f", currentDistance))m)"
                )
            }
            
            // Check if approach angle is reasonable for a driving route
            if let approachAngle = approachAnalysis.approachAngle {
                let poiBearing = calculateBearing(from: userLocation, to: poiLocation)
                let angleDifference = abs(approachAngle - poiBearing)
                let normalizedAngleDiff = min(angleDifference, 360 - angleDifference)
                
                // If driving and approach angle is very poor (e.g., driving away), reject
                if isMovingAtDrivingSpeed && normalizedAngleDiff > 120 {
                    return VisitValidationResult(
                        isValid: false,
                        reason: "Poor approach angle for driving: \(String(format: "%.0f", normalizedAngleDiff))° off course"
                    )
                }
            }
            
            // Check if slowing down appropriately for POI
            if approachAnalysis.isSlowingDown && currentDistance <= poi.radius * 2.0 {
                return VisitValidationResult(
                    isValid: true,
                    reason: "Valid approach: slowing down near POI (\(String(format: "%.1f", currentUserSpeed)) mph, \(String(format: "%.0f", currentDistance))m away)"
                )
            }
        }
        
        // For walking tours, check if user has stopped or slowed significantly
        if currentTour?.tourType == .walking && currentUserSpeed <= 3.0 && currentDistance <= poi.radius {
            return VisitValidationResult(
                isValid: true,
                reason: "Valid walking visit: stopped near POI (\(String(format: "%.1f", currentUserSpeed)) mph, \(String(format: "%.0f", currentDistance))m away)"
            )
        }
        
        return nil // No specific trajectory validation needed
    }
    
    private func analyzeApproachPattern(to targetLocation: CLLocation) -> ApproachAnalysis {
        guard locationHistory.count >= 3 else {
            return ApproachAnalysis(isApproaching: false, isMovingAway: false, isSlowingDown: false, approachAngle: nil)
        }
        
        // Calculate distances for last 3 positions
        let distances = locationHistory.suffix(3).map { $0.distance(from: targetLocation) }
        let speeds = speedHistory.suffix(3).map { $0.speed }
        
        // Determine if approaching (distances decreasing)
        let isApproaching = distances.count >= 2 && distances[1] > distances[0]
        let isMovingAway = distances.count >= 2 && distances[1] < distances[0]
        
        // Determine if slowing down
        let isSlowingDown = speeds.count >= 2 && speeds[1] > speeds[0]
        
        // Calculate approach angle if moving
        var approachAngle: CLLocationDirection?
        if let currentHeading = currentHeading {
            approachAngle = currentHeading
        }
        
        return ApproachAnalysis(
            isApproaching: isApproaching,
            isMovingAway: isMovingAway,
            isSlowingDown: isSlowingDown,
            approachAngle: approachAngle
        )
    }
    
    private func markPOIAsVisited(_ poi: PointOfInterest, session: VisitSession) async throws {
        poi.isVisited = true
        poi.visitedAt = session.startTime
        poi.dwellTime = Date().timeIntervalSince(session.startTime)
        
        try await dataService.poiRepository.save(poi)
        
        print("✅ POI marked as visited: \(poi.name)")
    }
}

// MARK: - Supporting Types

struct VisitSession {
    let id: UUID
    let poi: PointOfInterest
    let startTime: Date
    let startLocation: CLLocation
    let requiredDwellTime: TimeInterval
    
    init(poi: PointOfInterest, startTime: Date, startLocation: CLLocation, requiredDwellTime: TimeInterval) {
        self.id = UUID()
        self.poi = poi
        self.startTime = startTime
        self.startLocation = startLocation
        self.requiredDwellTime = requiredDwellTime
    }
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var isComplete: Bool {
        elapsedTime >= requiredDwellTime
    }
    
    func calculateProgress(currentTime: Date = Date()) -> VisitProgress {
        let elapsed = currentTime.timeIntervalSince(startTime)
        let percentage = min(elapsed / requiredDwellTime * 100, 100)
        let remaining = max(requiredDwellTime - elapsed, 0)
        
        return VisitProgress(
            percentage: percentage,
            elapsedTime: elapsed,
            remainingTime: remaining,
            isComplete: elapsed >= requiredDwellTime
        )
    }
}

struct VisitCandidate {
    let poi: PointOfInterest
    let firstDetectionTime: Date
    let lastValidationTime: Date
    let validationAttempts: Int
}

struct VisitValidationResult {
    let isValid: Bool
    let reason: String
}

struct CompletedVisit {
    let id: UUID
    let poiId: UUID
    let tourId: UUID
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let startLocation: CLLocation
    let endLocation: CLLocation?
    let wasAudioPlayed: Bool
}

struct VisitStatistics {
    let totalVisits: Int
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let audioPlayedCount: Int
    let audioPlayedPercentage: Double
    let lastVisitDate: Date?
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedAverageDuration: String {
        let minutes = Int(averageDuration) / 60
        let seconds = Int(averageDuration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

// TourProgress is defined in DataService.swift

struct VisitProgress {
    let percentage: Double
    let elapsedTime: TimeInterval
    let remainingTime: TimeInterval
    let isComplete: Bool
}

struct VisitEvent {
    let type: VisitEventType
    let poi: PointOfInterest
    let session: VisitSession
    let timestamp: Date
    let completedVisit: CompletedVisit?
    
    init(type: VisitEventType, poi: PointOfInterest, session: VisitSession, timestamp: Date, completedVisit: CompletedVisit? = nil) {
        self.type = type
        self.poi = poi
        self.session = session
        self.timestamp = timestamp
        self.completedVisit = completedVisit
    }
}

enum VisitEventType {
    case sessionStarted
    case visitCompleted
    case sessionCancelled
}

enum VisitSessionUpdate {
    case started(session: VisitSession)
    case progressUpdated(progress: VisitProgress)
    case ended(wasValid: Bool)
}

struct SpeedReading {
    let speed: Double // mph
    let timestamp: Date
    let location: CLLocation
    
    var ageInSeconds: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    var isStale: Bool {
        ageInSeconds > 30.0 // Consider readings older than 30 seconds stale
    }
}

struct ApproachAnalysis {
    let isApproaching: Bool      // Getting closer to target
    let isMovingAway: Bool       // Getting farther from target
    let isSlowingDown: Bool      // Speed decreasing
    let approachAngle: CLLocationDirection? // Direction of approach
    
    var isValidApproach: Bool {
        return isApproaching && !isMovingAway
    }
    
    var isStopping: Bool {
        return isSlowingDown && !isMovingAway
    }
}

enum VisitTrackingError: LocalizedError {
    case invalidVisitConditions(String)
    case noActiveSession
    case locationAccuracyInsufficient
    case poiAlreadyVisited
    
    var errorDescription: String? {
        switch self {
        case .invalidVisitConditions(let reason):
            return "Invalid visit conditions: \(reason)"
        case .noActiveSession:
            return "No active visit session found"
        case .locationAccuracyInsufficient:
            return "GPS accuracy is insufficient for visit tracking"
        case .poiAlreadyVisited:
            return "Point of interest has already been visited"
        }
    }
}