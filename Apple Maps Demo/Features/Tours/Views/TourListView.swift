import SwiftUI

struct TourListView: View {
    @StateObject private var viewModel = TourViewModel()
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Button
                filterSection
                
                // Active Filters (if any)
                if viewModel.hasActiveFilters || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    activeFiltersSection
                }
                
                // Results Count and Sort
                resultsSection
                
                // Tour Categories
                if viewModel.selectedCategory == nil {
                    categoriesSection
                        .background(Color(.systemGroupedBackground))
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
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search tours...")
            .onChange(of: searchText) { _, newValue in
                viewModel.updateSearchQuery(newValue)
            }
            .onAppear {
                viewModel.loadTours()
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            TourFilterSheet(viewModel: viewModel)
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        HStack {
            Spacer()
            
            // Filter Button
            Button(action: { showingFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18))
                    Text("Filter")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Active Filters Section
    
    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Search filter chip
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    FilterChip(
                        title: "Search: \"\(searchText)\"",
                        systemImage: "magnifyingglass",
                        isActive: true,
                        onRemove: { 
                            searchText = ""
                            viewModel.updateSearchQuery("")
                        }
                    )
                }
                
                if let category = viewModel.selectedCategory {
                    FilterChip(
                        title: category.rawValue,
                        systemImage: category.iconName,
                        isActive: true,
                        onRemove: { viewModel.setSelectedCategory(nil) }
                    )
                }
                
                ForEach(viewModel.activeFilterTags, id: \.self) { tag in
                    FilterChip(
                        title: tag,
                        isActive: true,
                        onRemove: { viewModel.removeFilter(tag) }
                    )
                }
                
                if viewModel.hasActiveFilters || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Clear All") {
                        searchText = ""
                        viewModel.clearAllFilters()
                        isSearching = false
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 40)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        HStack {
            Text("\(max(0, viewModel.filteredTours.count)) tours found")
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
                        .frame(width: 8, height: 6)
                }
                .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 28)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(TourCategory.allCases, id: \.self) { category in
                CategoryCard(
                    category: category,
                    tourCount: viewModel.getTourCount(for: category),
                    onTap: { viewModel.setSelectedCategory(category) }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(height: 220)
    }
    
    // MARK: - Tours List Section
    
    private var toursListSection: some View {
        List {
            ForEach(viewModel.filteredTours) { tour in
                NavigationLink(destination: TourDetailView(tour: tour)) {
                    TourRowView(
                        tour: tour,
                        downloadProgress: viewModel.getDownloadProgress(for: tour),
                        onTap: { },
                        onDownload: { handleTourDownload(tour) },
                        onCancelDownload: { handleCancelDownload(tour) }
                    )
                }
                .listRowBackground(Color(.systemBackground))
                .listRowSeparator(.hidden)
                .padding(.vertical, 2)
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
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .opacity(0.3),
            alignment: .top
        )
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                ProgressView("Loading tours...")
                    .padding()
            } else if searchText.isEmpty && viewModel.selectedCategory == nil && !viewModel.hasActiveFilters {
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
                    viewModel.clearAllFilters()
                    isSearching = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Actions
    
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
            VStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(colorFromString(category.color))
                    .cornerRadius(20)
                
                VStack(spacing: 2) {
                    Text(category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("\(tourCount) tours")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 85)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
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
                .frame(width: 55, height: 55)
                .overlay(
                    Image(systemName: tour.category.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(colorFromString(tour.category.color))
                )
            
            // Tour Information
            VStack(alignment: .leading, spacing: 2) {
                Text(tour.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(tour.tourDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Duration and POI Count combined
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDuration(tour.estimatedDuration))
                            .font(.caption)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        Image(systemName: "mappin")
                            .font(.caption)
                        Text("\(tour.pointsOfInterest.count) stops")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    
                    Spacer()
                    
                    // Tour Type Badge (smaller and simpler)
                    Text(tour.tourType.rawValue.capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(colorFromString(tour.tourType.color))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(colorFromString(tour.tourType.color).opacity(0.15))
                        .cornerRadius(3)
                        .fixedSize()
                }
            }
            
            Spacer()
            
            // Download/Action Button
            downloadButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
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