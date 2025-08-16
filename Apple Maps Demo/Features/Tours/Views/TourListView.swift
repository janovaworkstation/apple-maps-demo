import SwiftUI

struct TourListView: View {
    @StateObject private var viewModel = TourViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: TourCategory? = nil
    @State private var showingFilterSheet = false
    @State private var selectedTour: Tour?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterSection
                
                // Tour Categories
                if selectedCategory == nil {
                    categoriesSection
                }
                
                // Tours List
                if viewModel.filteredTours.isEmpty {
                    emptyStateSection
                } else {
                    toursListSection
                }
            }
            .navigationTitle("Tours")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showingFilterSheet = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: { viewModel.refreshTours() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadTours()
            }
            .searchable(text: $searchText, prompt: "Search tours...")
            .onChange(of: searchText) { _, newValue in
                viewModel.updateSearchQuery(newValue)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            TourFilterSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedTour) { tour in
            TourDetailView(tour: tour)
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Active Filters
            if viewModel.hasActiveFilters || selectedCategory != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let category = selectedCategory {
                            FilterChip(
                                title: category.rawValue,
                                systemImage: category.iconName,
                                isActive: true,
                                onRemove: { selectedCategory = nil }
                            )
                        }
                        
                        ForEach(viewModel.activeFilterTags, id: \.self) { tag in
                            FilterChip(
                                title: tag,
                                isActive: true,
                                onRemove: { viewModel.removeFilter(tag) }
                            )
                        }
                        
                        if viewModel.hasActiveFilters {
                            Button("Clear All") {
                                viewModel.clearAllFilters()
                                selectedCategory = nil
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Results Count
            HStack {
                Text("\(viewModel.filteredTours.count) tours found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Sort Options
                Menu {
                    Button("Name A-Z") { viewModel.setSortOption(.nameAscending) }
                    Button("Name Z-A") { viewModel.setSortOption(.nameDescending) }
                    Button("Duration (Short)") { viewModel.setSortOption(.durationAscending) }
                    Button("Duration (Long)") { viewModel.setSortOption(.durationDescending) }
                    Button("Recently Added") { viewModel.setSortOption(.recentlyAdded) }
                    Button("Popular") { viewModel.setSortOption(.popularity) }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(TourCategory.allCases, id: \.self) { category in
                    CategoryCard(
                        category: category,
                        tourCount: viewModel.getTourCount(for: category),
                        onTap: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Tours List Section
    
    private var toursListSection: some View {
        List {
            ForEach(viewModel.filteredTours) { tour in
                TourRowView(
                    tour: tour,
                    downloadProgress: viewModel.getDownloadProgress(for: tour),
                    onTap: { handleTourTap(tour) },
                    onDownload: { handleTourDownload(tour) },
                    onCancelDownload: { handleCancelDownload(tour) }
                )
                .listRowBackground(Color(.systemBackground))
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading tours...")
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.refreshToursAsync()
        }
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                ProgressView("Loading tours...")
                    .padding()
            } else if searchText.isEmpty && selectedCategory == nil && !viewModel.hasActiveFilters {
                // No tours available
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No Tours Available")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Check back later for new tours or try refreshing.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Refresh") {
                    viewModel.refreshTours()
                }
                .buttonStyle(.borderedProminent)
            } else {
                // No search results
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Try adjusting your search terms or filters.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Clear Filters") {
                    searchText = ""
                    selectedCategory = nil
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Actions
    
    private func handleTourTap(_ tour: Tour) {
        selectedTour = tour
    }
    
    private func handleTourDownload(_ tour: Tour) {
        Task {
            await viewModel.downloadTour(tour)
        }
    }
    
    private func handleCancelDownload(_ tour: Tour) {
        viewModel.cancelDownload(for: tour)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: TourCategory
    let tourCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: category.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(colorFromString(category.color))
                    .cornerRadius(25)
                
                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(tourCount) tours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Tour Row View

struct TourRowView: View {
    let tour: Tour
    let downloadProgress: Double?
    let onTap: () -> Void
    let onDownload: () -> Void
    let onCancelDownload: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Tour Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: tour.category.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(colorFromString(tour.category.color))
                )
            
            // Tour Information
            VStack(alignment: .leading, spacing: 4) {
                Text(tour.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(tour.tourDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Duration
                    Label(formatDuration(tour.estimatedDuration), systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // POI Count
                    Label("\(tour.pointsOfInterest.count) stops", systemImage: "mappin")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Tour Type Badge
                    Text(tour.tourType.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(colorFromString(tour.tourType.color))
                        .cornerRadius(6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            
            Spacer()
            
            // Download/Action Button
            downloadButton
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    @ViewBuilder
    private var downloadButton: some View {
        if let progress = downloadProgress {
            if progress < 1.0 {
                // Downloading
                VStack(spacing: 4) {
                    Button(action: onCancelDownload) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    
                    CircularProgressView(progress: progress)
                        .frame(width: 20, height: 20)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                // Downloaded
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
            }
        } else {
            // Not downloaded
            Button(action: onDownload) {
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
            }
        }
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

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isActive: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.caption)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            if isActive {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
            }
        }
        .foregroundColor(isActive ? .white : .blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.blue : Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Tour Filter Sheet

struct TourFilterSheet: View {
    @ObservedObject var viewModel: TourViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tour Type") {
                    ForEach(TourType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundColor(colorFromString(type.color))
                                .frame(width: 20)
                            
                            Text(type.rawValue)
                            
                            Spacer()
                            
                            if viewModel.selectedTourTypes.contains(type) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleTourType(type)
                        }
                    }
                }
                
                Section("Duration") {
                    ForEach(DurationFilter.allCases, id: \.self) { filter in
                        HStack {
                            Text(filter.displayName)
                            
                            Spacer()
                            
                            if viewModel.selectedDurationFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.setDurationFilter(filter)
                        }
                    }
                }
                
                Section("Download Status") {
                    ForEach(DownloadFilter.allCases, id: \.self) { filter in
                        HStack {
                            Text(filter.displayName)
                            
                            Spacer()
                            
                            if viewModel.selectedDownloadFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.setDownloadFilter(filter)
                        }
                    }
                }
            }
            .navigationTitle("Filter Tours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        viewModel.clearAllFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
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

#Preview {
    TourListView()
}