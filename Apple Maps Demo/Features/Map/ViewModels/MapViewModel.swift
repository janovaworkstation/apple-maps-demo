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
    
    private let locationManager = LocationManager.shared
    private let audioManager = AudioManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadMockData()
    }
    
    private func setupBindings() {
        // Monitor location updates
        locationManager.$currentLocation
            .sink { [weak self] location in
                self?.userLocation = location
                self?.updateCameraIfNeeded(for: location)
                self?.checkNearbyPOIs(location: location)
            }
            .store(in: &cancellables)
        
        // Monitor region entries
        NotificationCenter.default.publisher(for: .didEnterRegion)
            .sink { [weak self] notification in
                if let regionId = notification.userInfo?["regionId"] as? String,
                   let poiId = UUID(uuidString: regionId) {
                    self?.handlePOIEntry(poiId: poiId)
                }
            }
            .store(in: &cancellables)
    }
    
    func startLocationUpdates() {
        Task {
            let status = await locationManager.requestAuthorization()
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.startUpdatingLocation()
                startMonitoringPOIs()
            }
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopAllMonitoring()
    }
    
    private func startMonitoringPOIs() {
        for poi in pointsOfInterest {
            locationManager.startMonitoring(poi: poi)
        }
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
    
    private func checkNearbyPOIs(location: CLLocation?) {
        guard let location = location else { return }
        
        for poi in pointsOfInterest {
            if poi.isWithinRange(of: location) && !poi.isVisited {
                // Trigger audio for nearby POI
                handlePOIEntry(poiId: poi.id)
            }
        }
    }
    
    private func handlePOIEntry(poiId: UUID) {
        guard let poi = pointsOfInterest.first(where: { $0.id == poiId }) else { return }
        
        if !poi.isVisited {
            markPOIAsVisited(poi)
            playAudioForPOI(poi)
        }
    }
    
    private func markPOIAsVisited(_ poi: PointOfInterest) {
        if let index = pointsOfInterest.firstIndex(where: { $0.id == poi.id }) {
            pointsOfInterest[index].isVisited = true
            pointsOfInterest[index].visitedAt = Date()
            visitedPOIs.insert(poi.id)
        }
    }
    
    private func playAudioForPOI(_ poi: PointOfInterest) {
        Task {
            if let audioContent = poi.audioContent,
               let localURL = audioContent.localURL() {
                try? await audioManager.playAudio(from: localURL, for: poi)
            }
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
    
    private func loadMockData() {
        // Create sample tour with POIs
        let tour = Tour(
            name: "Historic Downtown Tour",
            description: "Explore the historic landmarks of downtown",
            estimatedDuration: 3600
        )
        
        let poi1 = PointOfInterest(
            tourId: tour.id,
            name: "City Hall",
            description: "Built in 1890, this historic building...",
            latitude: 37.7749,
            longitude: -122.4194
        )
        
        let poi2 = PointOfInterest(
            tourId: tour.id,
            name: "Central Park",
            description: "A beautiful green space in the heart of the city...",
            latitude: 37.7751,
            longitude: -122.4180,
            order: 1
        )
        
        pointsOfInterest = [poi1, poi2]
        currentTour = tour
        
        // Create route polyline
        let coordinates = pointsOfInterest.map { $0.coordinate }
        tourRoute = MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
}