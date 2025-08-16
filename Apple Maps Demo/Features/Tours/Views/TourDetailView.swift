import SwiftUI
import MapKit

struct TourDetailView: View {
    let tour: Tour
    @StateObject private var viewModel = TourDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPOI: PointOfInterest?
    @State private var showingMapDetail = false
    @State private var showingDownloadSheet = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tour Header
                tourHeaderSection
                
                // Quick Stats
                quickStatsSection
                
                // Map Preview
                mapPreviewSection
                
                // Description
                descriptionSection
                
                // Points of Interest
                poisSection
                
                // Tour Details
                tourDetailsSection
                
                // Download Section
                downloadSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tour.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.shareTour(tour) }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            viewModel.loadTourDetails(tour)
            setupMapCamera()
        }
        .sheet(isPresented: $showingMapDetail) {
            TourMapDetailView(tour: tour)
        }
        .sheet(isPresented: $showingDownloadSheet) {
            TourDownloadSheet(tour: tour, viewModel: viewModel)
        }
    }
    
    // MARK: - Tour Header
    
    private var tourHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tour Image/Icon
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorFromString(tour.category.color).opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: tour.category.iconName)
                            .font(.system(size: 30))
                            .foregroundColor(colorFromString(tour.category.color))
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    // Tour Type and Category
                    HStack(spacing: 12) {
                        Text(tour.tourType.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colorFromString(tour.tourType.color))
                            .cornerRadius(6)
                        
                        Text(tour.category.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(colorFromString(tour.category.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colorFromString(tour.category.color).opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    // Language
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(tour.language.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Rating and Reviews (if available)
            if let rating = viewModel.tourRating {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        Text("\(rating, specifier: "%.1f")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.reviewCount) reviews")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "clock",
                title: "Duration",
                value: formatDuration(tour.estimatedDuration),
                color: .blue
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                icon: "mappin",
                title: "Stops",
                value: "\(tour.pointsOfInterest.count)",
                color: .green
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                icon: "speedometer",
                title: "Type",
                value: tour.maxSpeed != nil ? "Driving" : "Walking",
                color: .orange
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func statItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Map Preview
    
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Route Preview")
                    .font(.headline)
                
                Spacer()
                
                Button("Full Map") {
                    showingMapDetail = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Map(position: $cameraPosition) {
                // POI markers
                ForEach(tour.pointsOfInterest) { poi in
                    Annotation(poi.name, coordinate: poi.coordinate) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                
                // Route polyline
                if let routeCoordinates = viewModel.routeCoordinates {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(.blue, lineWidth: 3)
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .allowsHitTesting(false)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Description
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Tour")
                .font(.headline)
            
            Text(tour.tourDescription)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Points of Interest
    
    private var poisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Points of Interest")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(tour.pointsOfInterest.enumerated()), id: \.element.id) { index, poi in
                    POIRowView(
                        poi: poi,
                        order: index + 1,
                        onTap: { selectedPOI = poi }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(item: $selectedPOI) { poi in
            POIDetailSheet(poi: poi)
        }
    }
    
    // MARK: - Tour Details
    
    private var tourDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 8) {
                detailRow(title: "Created", value: formatDate(tour.createdAt))
                detailRow(title: "Last Updated", value: formatDate(tour.lastModified))
                detailRow(title: "Language", value: getLanguageName(tour.language))
                
                if let maxSpeed = tour.maxSpeed {
                    detailRow(title: "Max Speed", value: "\(Int(maxSpeed)) mph")
                }
                
                detailRow(title: "Tour ID", value: String(tour.id.uuidString.prefix(8)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Download Section
    
    private var downloadSection: some View {
        VStack(spacing: 16) {
            if let progress = viewModel.downloadProgress {
                // Download in progress
                VStack(spacing: 12) {
                    HStack {
                        Text("Downloading Tour")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            viewModel.cancelDownload()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("\(Int(progress * 100))% complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(viewModel.downloadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if viewModel.isDownloaded {
                // Downloaded
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tour Downloaded")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Available offline • \(viewModel.downloadSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Remove") {
                        viewModel.removeTour()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            } else {
                // Not downloaded
                VStack(spacing: 12) {
                    Button(action: { showingDownloadSheet = true }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 20))
                            
                            Text("Download Tour")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Text("Download for offline access • \(viewModel.estimatedDownloadSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Start Tour Button
            Button(action: { viewModel.startTour(tour) }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                    
                    Text("Start Tour")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func setupMapCamera() {
        guard !tour.pointsOfInterest.isEmpty else { return }
        
        let coordinates = tour.pointsOfInterest.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.5,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.5
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func getLanguageName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "brown": return .brown
        case "purple": return .purple
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "gray": return .gray
        default: return .gray
        }
    }
}

// MARK: - POI Row View

struct POIRowView: View {
    let poi: PointOfInterest
    let order: Int
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Order Number
            Text("\(order)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(12)
            
            // POI Info
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !poi.poiDescription.isEmpty {
                    Text(poi.poiDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Tour Map Detail View

struct TourMapDetailView: View {
    let tour: Tour
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(tour.pointsOfInterest) { poi in
                Annotation(poi.name, coordinate: poi.coordinate) {
                    VStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        
                        Text(poi.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white)
                            .cornerRadius(4)
                            .shadow(radius: 1)
                    }
                }
            }
            
            if tour.pointsOfInterest.count > 1 {
                MapPolyline(coordinates: tour.pointsOfInterest.map { $0.coordinate })
                    .stroke(.blue, lineWidth: 3)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .navigationTitle("Tour Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Tour Download Sheet

struct TourDownloadSheet: View {
    let tour: Tour
    @ObservedObject var viewModel: TourDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuality: AudioQuality = .medium
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Download Tour")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Download this tour for offline access")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Audio Quality")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    qualityOption(.low, size: "5.2 MB", description: "Good for limited storage")
                    qualityOption(.medium, size: "12.8 MB", description: "Balanced quality and size")
                    qualityOption(.high, size: "28.4 MB", description: "Best audio quality")
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button("Download Tour") {
                    viewModel.downloadTour(tour, quality: selectedQuality)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                
                Text("Download will use your current network connection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Download Options")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func qualityOption(_ quality: AudioQuality, size: String, description: String) -> some View {
        Button(action: { selectedQuality = quality }) {
            HStack(spacing: 12) {
                Image(systemName: selectedQuality == quality ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedQuality == quality ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(quality.description)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(size)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            .padding()
            .background(selectedQuality == quality ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TourDetailView(tour: Tour(
        name: "Sample Tour",
        description: "A sample tour for preview",
        estimatedDuration: 3600,
        category: .historical,
        tourType: .walking
    ))
}