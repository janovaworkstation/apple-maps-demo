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
                        isSelected: mapSelection == poi.id.uuidString
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
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isVisited ? Color.green : Color.blue)
                .frame(width: 30, height: 30)
            
            Image(systemName: isVisited ? "checkmark.circle.fill" : "mappin.circle.fill")
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
            
            // Tour progress
            if viewModel.currentTour != nil {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.blue)
                    Text("\(viewModel.visitedPOIs.count)/\(viewModel.pointsOfInterest.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
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