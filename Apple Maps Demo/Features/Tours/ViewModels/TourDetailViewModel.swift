import Foundation
import Combine
import MapKit

@MainActor
final class TourDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var tourRating: Double?
    @Published var reviewCount: Int = 0
    @Published var downloadProgress: Double?
    @Published var isDownloaded: Bool = false
    @Published var downloadStatus: String = ""
    @Published var downloadSize: String = ""
    @Published var estimatedDownloadSize: String = ""
    @Published var routeCoordinates: [CLLocationCoordinate2D]?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var downloadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        print("📋 TourDetailViewModel initialized")
    }
    
    deinit {
        downloadTask?.cancel()
        cancellables.removeAll()
        print("🧹 TourDetailViewModel cleaned up")
    }
    
    // MARK: - Public Interface
    
    func loadTourDetails(_ tour: Tour) {
        isLoading = true
        
        Task {
            // Load tour metadata
            await loadTourMetadata(tour)
            
            // Generate route coordinates
            await generateRouteCoordinates(tour)
            
            // Check download status
            await checkDownloadStatus(tour)
            
            // Calculate estimated download size
            await calculateDownloadSize(tour)
            
            isLoading = false
        }
    }
    
    func downloadTour(_ tour: Tour, quality: AudioQuality = .medium) {
        guard downloadTask == nil else { return }
        
        downloadTask = Task {
            do {
                downloadProgress = 0.0
                downloadStatus = "Preparing download..."
                
                // Simulate download process
                for i in 1...100 {
                    guard !Task.isCancelled else { return }
                    
                    downloadProgress = Double(i) / 100.0
                    downloadStatus = "Downloading... \(i)%"
                    
                    // Simulate different phases of download
                    if i < 20 {
                        downloadStatus = "Downloading audio files..."
                    } else if i < 60 {
                        downloadStatus = "Processing content..."
                    } else if i < 90 {
                        downloadStatus = "Optimizing for offline use..."
                    } else {
                        downloadStatus = "Finalizing download..."
                    }
                    
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                
                // Complete download
                downloadProgress = nil
                isDownloaded = true
                downloadSize = getDownloadSizeString(for: quality)
                downloadStatus = "Download complete"
                
                print("✅ Tour downloaded successfully")
                
            } catch {
                await handleDownloadError(error)
            }
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadProgress = nil
        downloadStatus = ""
        print("❌ Download cancelled")
    }
    
    func removeTour() {
        // Implementation would remove the downloaded tour files
        isDownloaded = false
        downloadSize = ""
        print("🗑️ Tour removed from device")
    }
    
    func startTour(_ tour: Tour) {
        // Implementation would start the tour navigation
        print("🎯 Starting tour: \(tour.name)")
        
        // This would typically:
        // 1. Set the current tour in the app state
        // 2. Navigate to the map view
        // 3. Start location tracking
        // 4. Begin geofencing setup
    }
    
    func shareTour(_ tour: Tour) {
        // Implementation would show share sheet
        print("🔗 Sharing tour: \(tour.name)")
        
        // This would typically create a share URL or tour data
        // and present the system share sheet
    }
    
    // MARK: - Private Methods
    
    private func loadTourMetadata(_ tour: Tour) async {
        // Simulate loading tour ratings and reviews
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Mock data - in real app, this would come from a server
        tourRating = Double.random(in: 3.5...5.0)
        reviewCount = Int.random(in: 10...150)
    }
    
    private func generateRouteCoordinates(_ tour: Tour) async {
        guard tour.pointsOfInterest.count > 1 else { return }
        
        // For now, just connect POIs in order
        // In a real app, this might use routing APIs to generate actual routes
        routeCoordinates = tour.pointsOfInterest.map { $0.coordinate }
    }
    
    private func checkDownloadStatus(_ tour: Tour) async {
        // Implementation would check if tour is already downloaded
        // For now, randomly set some tours as downloaded
        isDownloaded = tour.id.uuidString.hashValue % 3 == 0
        
        if isDownloaded {
            downloadSize = "15.2 MB"
        }
    }
    
    private func calculateDownloadSize(_ tour: Tour) async {
        // Calculate estimated download size based on tour content
        let baseSizePerPOI = 2.5 // MB per POI
        let totalPOIs = Double(tour.pointsOfInterest.count)
        let estimatedSize = totalPOIs * baseSizePerPOI
        
        estimatedDownloadSize = String(format: "%.1f MB", estimatedSize)
    }
    
    private func getDownloadSizeString(for quality: AudioQuality) -> String {
        switch quality {
        case .low:
            return "5.2 MB"
        case .medium:
            return "12.8 MB"
        case .high:
            return "28.4 MB"
        case .lossless:
            return "45.6 MB"
        }
    }
    
    private func handleError(_ error: Error) async {
        isLoading = false
        errorMessage = error.localizedDescription
        print("❌ TourDetailViewModel Error: \(error)")
        
        // Auto-dismiss error after 5 seconds
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        errorMessage = nil
    }
    
    private func handleDownloadError(_ error: Error) async {
        downloadTask = nil
        downloadProgress = nil
        downloadStatus = "Download failed"
        
        print("❌ Download Error: \(error)")
        
        // Show error for 3 seconds then clear
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        downloadStatus = ""
    }
}

// MARK: - TourDetailViewModel Extensions

extension TourDetailViewModel {
    enum TourDetailError: LocalizedError {
        case tourNotFound
        case downloadFailed(String)
        case networkError
        case storageError
        
        var errorDescription: String? {
            switch self {
            case .tourNotFound:
                return "Tour not found"
            case .downloadFailed(let message):
                return "Download failed: \(message)"
            case .networkError:
                return "Network connection error"
            case .storageError:
                return "Storage error"
            }
        }
    }
}