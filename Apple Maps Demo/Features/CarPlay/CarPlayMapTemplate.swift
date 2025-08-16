//
//  CarPlayMapTemplate.swift
//  Apple Maps Demo
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CarPlay
import MapKit
import Combine

@MainActor
class CarPlayMapTemplate: NSObject {
    
    // MARK: - Properties
    private let interfaceController: CPInterfaceController
    private let audioManager: AudioManager
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    // Template and map view
    private(set) var template: CPMapTemplate
    private var mapView: MKMapView?
    private var currentTour: Tour?
    
    // Delegate
    weak var delegate: CarPlayTemplateDelegate?
    
    // MARK: - Initialization
    
    init(interfaceController: CPInterfaceController, 
         audioManager: AudioManager, 
         locationManager: LocationManager) {
        
        self.interfaceController = interfaceController
        self.audioManager = audioManager
        self.locationManager = locationManager
        
        // Create the map template
        self.template = CPMapTemplate()
        
        super.init()
        
        setupMapTemplate()
        setupBindings()
        print("🗺️ CarPlayMapTemplate initialized")
    }
    
    deinit {
        cancellables.removeAll()
        print("🧹 CarPlayMapTemplate cleaned up")
    }
    
    // MARK: - Setup
    
    private func setupMapTemplate() {
        template.mapDelegate = self
        
        // Configure map buttons
        setupMapButtons()
        
        // Set up navigation bar buttons
        setupNavigationBarButtons()
        
        // Configure automatic content insets
        template.automaticallyHidesNavigationBar = false
        template.hidesButtonsWithNavigationBar = false
    }
    
    private func setupMapButtons() {
        var mapButtons: [CPMapButton] = []
        
        // Now Playing button
        let nowPlayingButton = CPMapButton { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestNowPlaying()
        }
        nowPlayingButton.image = UIImage(systemName: "music.note")
        mapButtons.append(nowPlayingButton)
        
        // Location button
        let locationButton = CPMapButton { [weak self] _ in
            self?.centerOnUserLocation()
        }
        locationButton.image = UIImage(systemName: "location")
        mapButtons.append(locationButton)
        
        template.mapButtons = mapButtons
    }
    
    private func setupNavigationBarButtons() {
        // Leading buttons
        let tourListButton = CPBarButton(title: "Tours") { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestTourList()
        }
        template.leadingNavigationBarButtons = [tourListButton]
        
        // Trailing buttons (audio controls)
        updateAudioControls()
    }
    
    private func setupBindings() {
        // Listen for audio state changes
        audioManager.$isPlaying
            .sink { [weak self] _ in
                self?.updateAudioControls()
            }
            .store(in: &cancellables)
        
        // Listen for tour changes
        audioManager.$currentTourPublic
            .sink { [weak self] tour in
                self?.currentTour = tour
                self?.updateMapForTour(tour)
            }
            .store(in: &cancellables)
        
        // Listen for POI changes
        audioManager.$currentPOI
            .sink { [weak self] _ in
                self?.updateCurrentLocationAnnotation()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func updateForCurrentTour() {
        updateMapForTour(currentTour)
        updateAudioControls()
        updateCurrentLocationAnnotation()
    }
    
    // MARK: - Private Methods
    
    private func updateAudioControls() {
        var trailingButtons: [CPBarButton] = []
        
        if audioManager.currentPOI != nil {
            // Play/Pause button
            let playPauseButton = CPBarButton(
                title: audioManager.isPlaying ? "Pause" : "Play"
            ) { [weak self] _ in
                self?.delegate?.carPlayTemplateDidRequestPlayPause()
            }
            trailingButtons.append(playPauseButton)
            
            // Skip buttons
            let skipBackButton = CPBarButton(title: "⏪") { [weak self] _ in
                self?.delegate?.carPlayTemplateDidRequestSkipBackward()
            }
            
            let skipForwardButton = CPBarButton(title: "⏩") { [weak self] _ in
                self?.delegate?.carPlayTemplateDidRequestSkipForward()
            }
            
            trailingButtons.append(contentsOf: [skipBackButton, skipForwardButton])
        }
        
        template.trailingNavigationBarButtons = trailingButtons
    }
    
    private func updateMapForTour(_ tour: Tour?) {
        guard let tour = tour else {
            clearMapAnnotations()
            return
        }
        
        displayTourOnMap(tour)
    }
    
    private func displayTourOnMap(_ tour: Tour) {
        guard let mapView = mapView else { return }
        
        // Clear existing annotations
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add POI annotations
        let annotations = tour.pointsOfInterest.enumerated().map { index, poi in
            let annotation = CarPlayPOIAnnotation(poi: poi, order: index + 1)
            return annotation
        }
        mapView.addAnnotations(annotations)
        
        // Add route polyline
        if tour.pointsOfInterest.count > 1 {
            let coordinates = tour.pointsOfInterest.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        // Zoom to fit tour
        zoomToFitTour(tour)
    }
    
    private func zoomToFitTour(_ tour: Tour) {
        guard let mapView = mapView, !tour.pointsOfInterest.isEmpty else { return }
        
        let coordinates = tour.pointsOfInterest.map { $0.coordinate }
        let region = MKCoordinateRegion.region(for: coordinates)
        
        // Add some padding for better view
        let paddedRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 1.2,
                longitudeDelta: region.span.longitudeDelta * 1.2
            )
        )
        
        mapView.setRegion(paddedRegion, animated: true)
    }
    
    private func centerOnUserLocation() {
        guard let mapView = mapView,
              let userLocation = locationManager.currentLocation else { return }
        
        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        mapView.setRegion(region, animated: true)
    }
    
    private func updateCurrentLocationAnnotation() {
        // This could highlight the current POI or update user location
        // Implementation depends on specific requirements
    }
    
    private func clearMapAnnotations() {
        mapView?.removeAnnotations(mapView?.annotations ?? [])
        mapView?.removeOverlays(mapView?.overlays ?? [])
    }
}

// MARK: - CPMapTemplateDelegate

extension CarPlayMapTemplate: CPMapTemplateDelegate {
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        // Handle trip start if implementing turn-by-turn navigation
        print("🚗 Started CarPlay trip")
    }
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, displayStyleFor maneuver: CPManeuver) -> CPManeuverDisplayStyle {
        // Return appropriate display style for maneuvers
        return .leadingSymbol
    }
    
    nonisolated func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        // Handle navigation cancellation
        print("🚗 CarPlay navigation cancelled")
    }
    
    nonisolated func mapTemplateDidBeginPanGesture(_ mapTemplate: CPMapTemplate) {
        // Handle pan gesture start
    }
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        // Handle pan gesture - delegate to main actor
        Task { @MainActor in
            guard let mapView = mapView else { return }
            
            let region = mapView.region
            
            var newCenter = region.center
            
            switch direction {
            case .up:
                newCenter.latitude += region.span.latitudeDelta * 0.1
            case .down:
                newCenter.latitude -= region.span.latitudeDelta * 0.1
            case .left:
                newCenter.longitude -= region.span.longitudeDelta * 0.1
            case .right:
                newCenter.longitude += region.span.longitudeDelta * 0.1
            default:
                break
            }
            
            let newRegion = MKCoordinateRegion(center: newCenter, span: region.span)
            mapView.setRegion(newRegion, animated: true)
        }
    }
    
    nonisolated func mapTemplateDidEndPanGesture(_ mapTemplate: CPMapTemplate) {
        // Handle pan gesture end
    }
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, shouldShowNotificationFor maneuver: CPManeuver) -> Bool {
        // Return whether to show notification for maneuver
        return true
    }
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, shouldUpdateNotificationFor maneuver: CPManeuver, with travelEstimates: CPTravelEstimates) -> Bool {
        // Return whether to update notification
        return true
    }
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, shouldShowNotificationFor navigationAlert: CPNavigationAlert) -> Bool {
        // Return whether to show navigation alert
        return true
    }
    
    private nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, willShow maneuver: CPManeuver) {
        // Handle maneuver will show
    }
    
    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, willShow navigationAlert: CPNavigationAlert) {
        // Handle navigation alert will show
    }
    
    nonisolated func mapTemplateWillDismissNavigationAlert(_ mapTemplate: CPMapTemplate) {
        // Handle navigation alert dismissal
    }
    
    nonisolated func mapTemplateDidDismissNavigationAlert(_ mapTemplate: CPMapTemplate) {
        // Handle navigation alert dismissed
    }
    
    func mapTemplate(_ mapTemplate: CPMapTemplate, mapViewFor trip: CPTrip) -> MKMapView {
        // Create and return map view for trip
        let mapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        self.mapView = mapView
        
        // Apply current tour to the new map view
        if let tour = currentTour {
            displayTourOnMap(tour)
        }
        
        return mapView
    }
}

// MARK: - MKMapViewDelegate

extension CarPlayMapTemplate: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let poiAnnotation = annotation as? CarPlayPOIAnnotation else {
            return nil
        }
        
        let identifier = "CarPlayPOIAnnotation"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        
        annotationView.annotation = annotation
        annotationView.markerTintColor = poiAnnotation.poi.isVisited ? .green : .blue
        annotationView.glyphText = "\(poiAnnotation.order)"
        annotationView.canShowCallout = true
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4.0
            return renderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // Handle POI selection
        guard let poiAnnotation = view.annotation as? CarPlayPOIAnnotation else { return }
        
        // Could trigger audio for this POI or show additional info
        print("🎯 Selected POI: \(poiAnnotation.poi.name)")
    }
}

// MARK: - Supporting Classes

class CarPlayPOIAnnotation: NSObject, MKAnnotation {
    let poi: PointOfInterest
    let order: Int
    
    var coordinate: CLLocationCoordinate2D {
        return poi.coordinate
    }
    
    var title: String? {
        return poi.name
    }
    
    var subtitle: String? {
        return poi.poiDescription
    }
    
    init(poi: PointOfInterest, order: Int) {
        self.poi = poi
        self.order = order
    }
}

// MARK: - Extensions

extension MKCoordinateRegion {
    static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }
        
        if coordinates.count == 1 {
            return MKCoordinateRegion(
                center: coordinates[0],
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
        }
        
        let minLat = coordinates.map { $0.latitude }.min()!
        let maxLat = coordinates.map { $0.latitude }.max()!
        let minLon = coordinates.map { $0.longitude }.min()!
        let maxLon = coordinates.map { $0.longitude }.max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01),
            longitudeDelta: max(maxLon - minLon, 0.01)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}