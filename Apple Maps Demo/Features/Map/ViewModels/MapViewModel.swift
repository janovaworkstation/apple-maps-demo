import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
class MapViewModel: ObservableObject {
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var pointsOfInterest: [PointOfInterest] = []
    @Published var currentTour: Tour?
    @Published var tourRoute: MKPolyline?
    @Published var visitedPOIs: Set<UUID> = []
    @Published var isOnline = true
    @Published var userLocation: CLLocation?
    
    // Phase 4: Enhanced State
    @Published var currentVisitSession: VisitSession?
    @Published var tourProgress: TourProgressData?
    @Published var monitoredRegions: [POIRegion] = []
    @Published var isGeofencingActive = false
    @Published var visitStatistics: VisitStatistics?
    
    private let locationManager = LocationManager.shared
    private let audioManager = AudioManager()
    
    // Phase 4: New Services
    private let geofenceService = GeofenceService.shared
    private let visitTrackingService = VisitTrackingService.shared
    private let backgroundTaskService = BackgroundTaskService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        setupBackgroundTasks()
        // Load mock data once we have location
    }
    
    private func setupBindings() {
        // Monitor location updates
        locationManager.$currentLocation
            .sink { [weak self] location in
                self?.userLocation = location
                self?.updateCameraIfNeeded(for: location)
                
                // Load mock POIs near user location if we haven't already
                if self?.pointsOfInterest.isEmpty == true, let userLocation = location {
                    self?.loadMockDataNear(location: userLocation)
                }
                
                // Phase 4: Update geofencing based on location
                Task {
                    await self?.handleLocationUpdate(location)
                }
            }
            .store(in: &cancellables)
        
        // Phase 4: Monitor geofence events
        geofenceService.regionEvents
            .sink { [weak self] event in
                Task {
                    await self?.handleRegionEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Phase 4: Monitor visit tracking events
        visitTrackingService.visitEvents
            .sink { [weak self] event in
                self?.handleVisitEvent(event)
            }
            .store(in: &cancellables)
        
        // Phase 4: Monitor visit session updates
        visitTrackingService.sessionUpdates
            .sink { [weak self] update in
                self?.handleSessionUpdate(update)
            }
            .store(in: &cancellables)
        
        // Monitor geofence status updates
        geofenceService.monitoringStatus
            .sink { [weak self] status in
                self?.handleGeofenceStatusUpdate(status)
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundTasks() {
        // Register background tasks for location processing
        backgroundTaskService.registerBackgroundTasks()
    }
    
    func startLocationUpdates() {
        Task {
            let status = await locationManager.requestAuthorization()
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.startUpdatingLocation()
                
                // Phase 4: Start intelligent geofencing when we have a tour
                if let tour = currentTour {
                    try? await startTourGeofencing(tour: tour)
                }
            }
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        
        // Phase 4: Stop geofencing and visit tracking
        Task {
            try? await stopTourGeofencing()
        }
    }
    
    // Phase 4: Enhanced Tour Management
    func startTourGeofencing(tour: Tour) async throws {
        print("🎯 Starting tour geofencing for: \(tour.name)")
        print("🎯 Tour type: \(tour.tourType.rawValue)")
        
        // Configure visit tracking service for this tour type
        visitTrackingService.setCurrentTour(tour)
        
        // Configure audio manager for this tour type
        audioManager.setCurrentTour(tour)
        
        try await geofenceService.startMonitoring(tour: tour, userLocation: userLocation)
        isGeofencingActive = true
        
        // Update monitored regions display
        monitoredRegions = geofenceService.getMonitoredRegions()
        
        // Initialize tour progress tracking
        tourProgress = try await visitTrackingService.getTourProgress(for: tour.id)
        visitStatistics = try await visitTrackingService.getVisitStatistics(for: tour.id)
        
        print("✅ Tour geofencing started with \(monitoredRegions.count) regions")
    }
    
    func stopTourGeofencing() async throws {
        print("🛑 Stopping tour geofencing")
        
        // Clear visit tracking service configuration
        visitTrackingService.setCurrentTour(nil)
        
        // Clear audio manager configuration
        audioManager.setCurrentTour(nil as Tour?)
        
        try await geofenceService.stopMonitoring()
        isGeofencingActive = false
        monitoredRegions.removeAll()
        currentVisitSession = nil
        
        print("✅ Tour geofencing stopped")
    }
    
    private func updateCameraIfNeeded(for location: CLLocation?) {
        guard let location = location else { return }
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        
        withAnimation {
            cameraPosition = .region(region)
        }
    }
    
    // MARK: - Phase 4: Event Handlers
    
    private func handleLocationUpdate(_ location: CLLocation?) async {
        guard let location = location else { return }
        
        // Update geofencing based on user movement
        if isGeofencingActive {
            try? await geofenceService.updateMonitoredRegions(userLocation: location)
            monitoredRegions = geofenceService.getMonitoredRegions()
        }
        
        // Handle background location updates
        await backgroundTaskService.handleBackgroundLocationUpdate(location)
    }
    
    private func handleRegionEvent(_ event: RegionEvent) async {
        print("🚨 Region event: \(event.type) for POI: \(event.poi.name)")
        
        switch event.type {
        case .entry:
            // Start visit session when user enters POI region
            if let userLocation = event.userLocation {
                do {
                    try await visitTrackingService.startVisitSession(for: event.poi, userLocation: userLocation)
                    print("✅ Visit session started for \(event.poi.name)")
                } catch {
                    print("❌ Failed to start visit session: \(error)")
                }
            }
            
        case .exit:
            // End visit session when user exits POI region
            if visitTrackingService.getCurrentVisitSession()?.poi.id == event.poi.id {
                try? await visitTrackingService.endVisitSession(for: event.poi)
                print("🏁 Visit session ended for \(event.poi.name)")
            }
        }
        
        // Handle background region events
        await backgroundTaskService.handleBackgroundRegionEvent(event)
    }
    
    private func handleVisitEvent(_ event: VisitEvent) {
        print("🎯 Visit event: \(event.type) for POI: \(event.poi.name)")
        
        switch event.type {
        case .sessionStarted:
            currentVisitSession = event.session
            
        case .visitCompleted:
            // Update local state
            if let index = pointsOfInterest.firstIndex(where: { $0.id == event.poi.id }) {
                pointsOfInterest[index].isVisited = true
                pointsOfInterest[index].visitedAt = event.timestamp
                visitedPOIs.insert(event.poi.id)
            }
            
            // Trigger audio playback for completed visit
            Task {
                await playAudioForPOI(event.poi)
                
                // Update progress after audio starts
                if let tour = currentTour {
                    tourProgress = try? await visitTrackingService.getTourProgress(for: tour.id)
                    visitStatistics = try? await visitTrackingService.getVisitStatistics(for: tour.id)
                }
            }
            
            currentVisitSession = nil
            
        case .sessionCancelled:
            currentVisitSession = nil
        }
    }
    
    private func handleSessionUpdate(_ update: VisitSessionUpdate) {
        switch update {
        case .started(let session):
            currentVisitSession = session
            
        case .progressUpdated(let progress):
            // Update UI with visit progress
            print("📊 Visit progress: \(Int(progress.percentage))%")
            
        case .ended(let wasValid):
            currentVisitSession = nil
            print(wasValid ? "✅ Visit completed successfully" : "❌ Visit session ended early")
        }
    }
    
    private func handleGeofenceStatusUpdate(_ status: GeofenceMonitoringStatus) {
        switch status {
        case .started(let tour, let regionCount):
            print("🎯 Geofencing started for \(tour.name) with \(regionCount) regions")
            isGeofencingActive = true
            
        case .stopped:
            print("🛑 Geofencing stopped")
            isGeofencingActive = false
            monitoredRegions.removeAll()
            
        case .regionsUpdated(let count):
            print("🔄 Monitored regions updated: \(count) regions")
            monitoredRegions = geofenceService.getMonitoredRegions()
            
        case .error(let error):
            print("❌ Geofencing error: \(error)")
            isGeofencingActive = false
        }
    }
    
    private func playAudioForPOI(_ poi: PointOfInterest) async {
        do {
            // Phase 4: Use enhanced AudioManager with auto-play functionality
            try await audioManager.autoPlayForPOIVisit(poi)
        } catch {
            print("❌ Failed to play audio for POI \(poi.name): \(error)")
        }
    }
    
    func centerOnUser() {
        if let location = userLocation {
            updateCameraIfNeeded(for: location)
        }
    }
    
    func centerOnPOI(_ poi: PointOfInterest) {
        let region = MKCoordinateRegion(
            center: poi.coordinate,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        )
        
        withAnimation {
            cameraPosition = .region(region)
        }
    }
    
    // MARK: - Mock Data
    
    private func loadMockDataNear(location: CLLocation) {
        // Create sample driving tour with POIs near user location
        let tour = Tour(
            name: "Local Area Driving Tour",
            description: "A scenic driving route with audio commentary for local landmarks",
            estimatedDuration: 1800, // 30 minutes
            category: .general,
            tourType: .driving, // Set as driving tour for testing
            maxSpeed: 35.0 // 35 mph max for city driving
        )
        
        // Create POIs with small offsets from user location (about 100-200 meters)
        let userCoord = location.coordinate
        
        let poi1 = PointOfInterest(
            tourId: tour.id,
            name: "Local Point of Interest",
            description: "An interesting location near your current position",
            latitude: userCoord.latitude + 0.001, // ~100m north
            longitude: userCoord.longitude + 0.001 // ~100m east
        )
        
        let poi2 = PointOfInterest(
            tourId: tour.id,
            name: "Nearby Landmark",
            description: "Another landmark within walking distance",
            latitude: userCoord.latitude - 0.0015, // ~150m south
            longitude: userCoord.longitude + 0.0005, // ~50m east
            order: 1
        )
        
        pointsOfInterest = [poi1, poi2]
        currentTour = tour
        
        // Create route polyline
        let coordinates = pointsOfInterest.map { $0.coordinate }
        tourRoute = MKPolyline(coordinates: coordinates, count: coordinates.count)
        
        print("Created \(pointsOfInterest.count) POIs near user location: \(userCoord)")
        
        // Phase 4: Start geofencing for the new tour
        Task {
            try? await startTourGeofencing(tour: tour)
        }
    }
}