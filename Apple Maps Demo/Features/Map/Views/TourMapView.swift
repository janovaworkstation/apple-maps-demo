import SwiftUI
import MapKit

struct TourMapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var mapSelection: String?
    @State private var showingPOIDetail = false
    @State private var selectedPOI: PointOfInterest?
    
    var body: some View {
        Map(position: $viewModel.cameraPosition, selection: $mapSelection) {
            // User location
            UserAnnotation()
            
            // Tour path
            if let route = viewModel.tourRoute {
                MapPolyline(route)
                    .stroke(.blue, lineWidth: 3)
            }
            
            // POI markers
            ForEach(viewModel.pointsOfInterest) { poi in
                Annotation(poi.name, coordinate: poi.coordinate) {
                    POIMarker(
                        poi: poi,
                        isVisited: poi.isVisited,
                        isSelected: mapSelection == poi.id.uuidString,
                        viewModel: viewModel
                    )
                    .onTapGesture {
                        selectedPOI = poi
                        showingPOIDetail = true
                    }
                }
                .tag(poi.id.uuidString)
                
                // Geofence circles
                MapCircle(center: poi.coordinate, radius: poi.radius)
                    .foregroundStyle(.blue.opacity(0.1))
                    .stroke(.blue.opacity(0.3), lineWidth: 1)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
        }
        .sheet(isPresented: $showingPOIDetail) {
            if let poi = selectedPOI {
                POIDetailView(poi: poi)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .overlay(alignment: .topLeading) {
            TourStatusBar(viewModel: viewModel)
        }
        .onAppear {
            viewModel.startLocationUpdates()
        }
        .onDisappear {
            viewModel.stopLocationUpdates()
        }
    }
}

struct POIMarker: View {
    let poi: PointOfInterest
    let isVisited: Bool
    let isSelected: Bool
    @ObservedObject var viewModel: MapViewModel
    
    // Phase 4: Enhanced marker state
    private var isInActiveSession: Bool {
        viewModel.currentVisitSession?.poi.id == poi.id
    }
    
    private var markerColor: Color {
        if isInActiveSession {
            return .orange
        } else if isVisited {
            return .green
        } else {
            return .blue
        }
    }
    
    private var markerIcon: String {
        if isInActiveSession {
            return "location.fill"
        } else if isVisited {
            return "checkmark.circle.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Phase 4: Animated visit session indicator
            if isInActiveSession {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isInActiveSession)
            }
            
            Circle()
                .fill(markerColor)
                .frame(width: 30, height: 30)
            
            Image(systemName: markerIcon)
                .foregroundColor(.white)
                .font(.system(size: 20))
            
            if isSelected {
                Circle()
                    .stroke(Color.orange, lineWidth: 3)
                    .frame(width: 35, height: 35)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.3), value: isInActiveSession)
    }
}

struct TourStatusBar: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Connection status
            HStack(spacing: 4) {
                Image(systemName: viewModel.isOnline ? "wifi" : "wifi.slash")
                    .foregroundColor(viewModel.isOnline ? .green : .gray)
                Text(viewModel.isOnline ? "Online" : "Offline")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // Phase 4: Enhanced tour progress with geofencing status
            if viewModel.currentTour != nil {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isGeofencingActive ? "location.fill" : "mappin.and.ellipse")
                        .foregroundColor(viewModel.isGeofencingActive ? .green : .blue)
                    Text("\(viewModel.visitedPOIs.count)/\(viewModel.pointsOfInterest.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if viewModel.isGeofencingActive {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            
            // Phase 4: Active visit session indicator
            if let session = viewModel.currentVisitSession {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text("Visiting \(session.poi.name)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.3), value: session.id)
            }
            
            // Phase 4: Geofence monitoring status
            if !viewModel.monitoredRegions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.circle")
                        .foregroundColor(.purple)
                    Text("\(viewModel.monitoredRegions.count) monitored")
                        .font(.caption2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
            }
        }
        .padding()
    }
}

struct POIDetailView: View {
    let poi: PointOfInterest
    @State private var isPlayingAudio = false
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(poi.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if poi.isVisited {
                        Label("Visited", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            // Description
            ScrollView {
                Text(poi.poiDescription)
                    .padding(.horizontal)
            }
            
            // Audio controls
            HStack {
                Button(action: playAudio) {
                    Label(
                        isPlayingAudio ? "Pause" : "Play Audio",
                        systemImage: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
    }
    
    private func playAudio() {
        // Toggle audio playback
        isPlayingAudio.toggle()
    }
    
    private func dismiss() {
        // Dismiss sheet
    }
}

#Preview {
    TourMapView()
}