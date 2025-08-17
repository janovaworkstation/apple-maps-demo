import Foundation
import Combine
import SwiftUI

@MainActor
final class TourViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var tours: [Tour] = []
    @Published var filteredTours: [Tour] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    
    // Filter State
    @Published var selectedCategory: TourCategory?
    @Published var selectedTourTypes: Set<TourType> = []
    @Published var selectedDurationFilter: DurationFilter?
    @Published var selectedDownloadFilter: DownloadFilter? = .all // Default to .all
    @Published var currentSortOption: SortOption = .nameAscending
    
    // Download Management
    @Published var downloadingTours: Set<UUID> = []
    @Published var downloadedTours: Set<UUID> = []
    @Published var downloadProgress: [UUID: Double] = [:]
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        selectedCategory != nil ||
        !selectedTourTypes.isEmpty ||
        selectedDurationFilter != nil ||
        (selectedDownloadFilter != nil && selectedDownloadFilter != .all) ||
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var activeFilterTags: [String] {
        var tags: [String] = []
        
        // Tour types
        tags.append(contentsOf: selectedTourTypes.map { $0.rawValue.capitalized })
        
        // Duration filter
        if let durationFilter = selectedDurationFilter {
            tags.append(durationFilter.displayName)
        }
        
        // Download filter
        if let downloadFilter = selectedDownloadFilter, downloadFilter != .all {
            tags.append(downloadFilter.displayName)
        }
        
        return tags
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var downloadTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    deinit {
        // Clean up synchronously to avoid capture issues
        for task in downloadTasks.values {
            task.cancel()
        }
        downloadTasks.removeAll()
        cancellables.removeAll()
        print("🧹 TourViewModel cleaned up")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Auto-filter when search query or filters change (debounced for search performance)
        Publishers.CombineLatest(
            Publishers.CombineLatest4(
                $searchQuery,
                $selectedTourTypes,
                $selectedDurationFilter,
                $selectedDownloadFilter
            ),
            $selectedCategory
        )
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
        
        // Auto-sort when sort option changes
        $currentSortOption
            .sink { [weak self] _ in
                self?.applySort()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    func loadTours() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task { // inherits @MainActor from this context
            // Load tours (mock data for now)
            let loadedTours = await generateMockTours()
            
            tours = loadedTours
            loadDownloadStatuses()
            applyFilters()
            
            isLoading = false
        }
    }
    
    func refreshTours() {
        tours.removeAll()
        filteredTours.removeAll()
        loadTours()
    }
    
    func refreshToursAsync() async {
        // For pull-to-refresh
        await MainActor.run {
            refreshTours()
        }
        
        // Wait for loading to complete
        while isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    func updateSearchQuery(_ query: String) {
        searchQuery = query
    }
    
    // MARK: - Filter Management
    
    func setSelectedCategory(_ category: TourCategory?) {
        selectedCategory = category
        // Apply filters immediately for category changes (bypass debounce for better UX)
        applyFilters()
    }
    
    func toggleTourType(_ type: TourType) {
        if selectedTourTypes.contains(type) {
            selectedTourTypes.remove(type)
        } else {
            selectedTourTypes.insert(type)
        }
    }
    
    func setDurationFilter(_ filter: DurationFilter?) {
        selectedDurationFilter = filter
    }
    
    func setDownloadFilter(_ filter: DownloadFilter?) {
        selectedDownloadFilter = filter
    }
    
    func setSortOption(_ option: SortOption) {
        currentSortOption = option
    }
    
    func removeFilter(_ tag: String) {
        // Remove filter by tag name
        if let tourType = TourType.allCases.first(where: { $0.rawValue.capitalized == tag }) {
            selectedTourTypes.remove(tourType)
        } else if DurationFilter.allCases.contains(where: { filter in filter.displayName == tag }) {
            selectedDurationFilter = nil
        } else if DownloadFilter.allCases.contains(where: { filter in filter.displayName == tag }) {
            selectedDownloadFilter = nil
        }
    }
    
    func clearAllFilters() {
        selectedCategory = nil
        selectedTourTypes.removeAll()
        selectedDurationFilter = nil
        selectedDownloadFilter = nil
        searchQuery = ""
    }
    
    // MARK: - Tour Management
    
    func getTourCount(for category: TourCategory) -> Int {
        tours.filter { $0.category == category }.count
    }
    
    func downloadTour(_ tour: Tour) async {
        guard !downloadingTours.contains(tour.id) else { return }
        
        downloadingTours.insert(tour.id)
        downloadProgress[tour.id] = 0.0
        
        let downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Simulate download process
                for i in 1...100 {
                    guard !Task.isCancelled else { return }
                    
                    // Explicitly hop to MainActor for state updates
                    await MainActor.run {
                        let progress = Double(i) / 100.0
                        // Ensure progress is valid before storing
                        if progress.isFinite && !progress.isNaN {
                            self.downloadProgress[tour.id] = progress
                        }
                    }
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                
                // Complete download - explicitly hop to MainActor
                await MainActor.run {
                    self.downloadingTours.remove(tour.id)
                    self.downloadedTours.insert(tour.id)
                    self.downloadProgress.removeValue(forKey: tour.id)
                    self.downloadTasks.removeValue(forKey: tour.id) // Fix memory leak
                    print("✅ Downloaded tour: \(tour.name)")
                }
                
            } catch {
                await self.handleDownloadError(tour, error)
            }
        }
        
        downloadTasks[tour.id] = downloadTask
    }
    
    func cancelDownload(for tour: Tour) {
        downloadTasks[tour.id]?.cancel()
        downloadTasks.removeValue(forKey: tour.id) // Remove task from dictionary
        downloadingTours.remove(tour.id)
        downloadProgress.removeValue(forKey: tour.id)
        
        print("❌ Cancelled download for: \(tour.name)")
    }
    
    func getDownloadProgress(for tour: Tour) -> Double? {
        if downloadedTours.contains(tour.id) {
            return 1.0
        }
        
        if let progress = downloadProgress[tour.id] {
            // Return only valid progress values
            return progress.isFinite && !progress.isNaN ? progress : nil
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func applyFilters() {
        var filtered = tours
        
        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { tour in
                tour.category == category
            }
        }
        
        // Apply search query
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            filtered = filtered.filter { tour in
                tour.name.localizedCaseInsensitiveContains(trimmedQuery) ||
                tour.tourDescription.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
        
        // Apply tour type filter
        if !selectedTourTypes.isEmpty {
            filtered = filtered.filter { tour in
                selectedTourTypes.contains(tour.tourType)
            }
        }
        
        // Apply duration filter
        if let durationFilter = selectedDurationFilter {
            filtered = filtered.filter { tour in
                durationFilter.matches(tour.estimatedDuration)
            }
        }
        
        // Apply download filter
        if let downloadFilter = selectedDownloadFilter {
            filtered = filtered.filter { tour in
                downloadFilter.matches(
                    isDownloaded: downloadedTours.contains(tour.id),
                    isDownloading: downloadingTours.contains(tour.id)
                )
            }
        }
        
        filteredTours = filtered
        applySort()
    }
    
    private func applySort() {
        filteredTours.sort { tour1, tour2 in
            switch currentSortOption {
            case .nameAscending:
                return tour1.name < tour2.name
            case .nameDescending:
                return tour1.name > tour2.name
            case .durationAscending:
                return tour1.estimatedDuration < tour2.estimatedDuration
            case .durationDescending:
                return tour1.estimatedDuration > tour2.estimatedDuration
            case .recentlyAdded:
                return tour1.createdAt > tour2.createdAt
            case .popularity:
                // Mock popularity - in real app would use actual metrics
                return tour1.name.count < tour2.name.count
            }
        }
    }
    
    private func loadDownloadStatuses() {
        // Load which tours are already downloaded
        // Use deterministic random for consistent mock state
        downloadedTours.removeAll()
        var rng = SeededRandomNumberGenerator(seed: 42)
        
        for tour in tours {
            if Bool.random(using: &rng) {
                downloadedTours.insert(tour.id)
            }
        }
    }
    
    private func generateMockTours() async -> [Tour] {
        let mockTours = [
            Tour(
                name: "Historic Downtown Walking Tour",
                description: "Explore the historic heart of the city with stories of its founding and development.",
                estimatedDuration: 2700, // 45 minutes
                category: .historical,
                tourType: .walking
            ),
            Tour(
                name: "Scenic Coastal Drive",
                description: "A beautiful coastal route with stunning ocean views and lighthouse stops.",
                estimatedDuration: 5400, // 90 minutes
                category: .nature,
                tourType: .driving,
                maxSpeed: 45.0
            ),
            Tour(
                name: "Urban Art & Culture Trail",
                description: "Discover street art, galleries, and cultural landmarks in the arts district.",
                estimatedDuration: 3600, // 60 minutes
                category: .cultural,
                tourType: .walking
            ),
            Tour(
                name: "Nature Trail Adventure",
                description: "Experience local flora and fauna on this guided nature walk.",
                estimatedDuration: 4500, // 75 minutes
                category: .nature,
                tourType: .walking
            ),
            Tour(
                name: "City Highlights Drive",
                description: "See all the major landmarks and attractions in this comprehensive city tour.",
                estimatedDuration: 7200, // 2 hours
                category: .general,
                tourType: .driving,
                maxSpeed: 35.0
            ),
            Tour(
                name: "Architectural Gems Walking Tour",
                description: "Admire the architectural diversity from Victorian to modern skyscrapers.",
                estimatedDuration: 3300, // 55 minutes
                category: .architecture,
                tourType: .walking
            )
        ]
        
        // Add mock POIs to each tour
        for tour in mockTours {
            addMockPOIs(to: tour)
        }
        
        return mockTours
    }
    
    private func addMockPOIs(to tour: Tour) {
        let baseLat = 37.7749 // San Francisco area
        let baseLon = -122.4194
        
        let poiCount = Int.random(in: 3...8)
        
        // Clear existing POIs first (for safety)
        tour.pointsOfInterest.removeAll()
        
        // Generate new POIs
        tour.pointsOfInterest = (0..<poiCount).map { i in
            PointOfInterest(
                tourId: tour.id,
                name: "Point of Interest \(i + 1)",
                description: "A fascinating location with rich history and cultural significance.",
                latitude: baseLat + Double.random(in: -0.01...0.01),
                longitude: baseLon + Double.random(in: -0.01...0.01),
                order: i
            )
        }
    }
    
    private func cancelAllDownloads() {
        for task in downloadTasks.values {
            task.cancel()
        }
        downloadTasks.removeAll()
    }
    
    private func handleError(_ error: Error) async {
        isLoading = false
        errorMessage = error.localizedDescription
        print("❌ TourViewModel Error: \(error)")
        
        // Auto-dismiss error after 5 seconds
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        errorMessage = nil
    }
    
    private func handleDownloadError(_ tour: Tour, _ error: Error) async {
        downloadingTours.remove(tour.id)
        downloadProgress.removeValue(forKey: tour.id)
        downloadTasks.removeValue(forKey: tour.id)
        
        print("❌ Download Error for \(tour.name): \(error)")
    }
}

// MARK: - Supporting Enums

enum SortOption: String, CaseIterable {
    case nameAscending = "nameAsc"
    case nameDescending = "nameDesc"
    case durationAscending = "durationAsc"
    case durationDescending = "durationDesc"
    case recentlyAdded = "recent"
    case popularity = "popular"
    
    var displayName: String {
        switch self {
        case .nameAscending: return "Name A-Z"
        case .nameDescending: return "Name Z-A"
        case .durationAscending: return "Duration (Short)"
        case .durationDescending: return "Duration (Long)"
        case .recentlyAdded: return "Recently Added"
        case .popularity: return "Popular"
        }
    }
}

enum DurationFilter: String, CaseIterable {
    case short = "short"        // < 30 minutes
    case medium = "medium"      // 30-60 minutes
    case long = "long"          // 60-120 minutes
    case extended = "extended"  // > 120 minutes
    
    var displayName: String {
        switch self {
        case .short: return "Short (< 30 min)"
        case .medium: return "Medium (30-60 min)"
        case .long: return "Long (1-2 hours)"
        case .extended: return "Extended (2+ hours)"
        }
    }
    
    func matches(_ duration: TimeInterval) -> Bool {
        let minutes = duration / 60
        
        switch self {
        case .short: return minutes < 30
        case .medium: return minutes >= 30 && minutes < 60
        case .long: return minutes >= 60 && minutes < 120
        case .extended: return minutes >= 120
        }
    }
}

enum DownloadFilter: String, CaseIterable {
    case all = "all"
    case downloaded = "downloaded"
    case notDownloaded = "notDownloaded"
    case downloading = "downloading"
    
    var displayName: String {
        switch self {
        case .all: return "All Tours"
        case .downloaded: return "Downloaded"
        case .notDownloaded: return "Not Downloaded"
        case .downloading: return "Downloading"
        }
    }
    
    func matches(isDownloaded: Bool, isDownloading: Bool) -> Bool {
        switch self {
        case .all: return true
        case .downloaded: return isDownloaded
        case .notDownloaded: return !isDownloaded && !isDownloading
        case .downloading: return isDownloading
        }
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}