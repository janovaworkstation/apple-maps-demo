import SwiftUI

struct AudioQueueView: View {
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var viewModel = AudioQueueViewModel()
    @State private var isReordering = false
    @State private var selectedPOI: PointOfInterest?
    @State private var showingPOIDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Queue Header
                queueHeaderSection
                
                // Queue List
                if viewModel.queueItems.isEmpty {
                    emptyQueueSection
                } else {
                    queueListSection
                }
                
                Spacer()
            }
            .navigationTitle("Audio Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !viewModel.queueItems.isEmpty {
                        Button(isReordering ? "Done" : "Edit") {
                            isReordering.toggle()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.setupAudioManager(audioManager)
            }
        }
        .sheet(isPresented: $showingPOIDetail) {
            if let poi = selectedPOI {
                POIDetailSheet(poi: poi)
            }
        }
    }
    
    // MARK: - Queue Header
    
    private var queueHeaderSection: some View {
        VStack(spacing: 12) {
            // Current Playing
            if let currentPOI = audioManager.currentPOI {
                HStack(spacing: 16) {
                    // Current POI Indicator
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now Playing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(currentPOI.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Progress Indicator
                    CircularProgressView(progress: viewModel.currentProgress)
                        .frame(width: 30, height: 30)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            
            // Queue Statistics
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In Queue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.queueItems.count)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.totalQueueTime)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty Queue Section
    
    private var emptyQueueSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Queue is Empty")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Points of interest will appear here as you explore the tour.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Queue List Section
    
    private var queueListSection: some View {
        List {
            ForEach(viewModel.queueItems) { item in
                QueueItemRow(
                    item: item,
                    isReordering: isReordering,
                    onTap: { handleItemTap(item) },
                    onPlay: { handlePlayItem(item) },
                    onRemove: { handleRemoveItem(item) }
                )
                .listRowBackground(Color(.systemBackground))
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }
            .onMove(perform: isReordering ? moveItems : nil)
            .onDelete(perform: isReordering ? nil : deleteItems)
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Actions
    
    private func handleItemTap(_ item: AudioQueueItem) {
        selectedPOI = item.poi
        showingPOIDetail = true
    }
    
    private func handlePlayItem(_ item: AudioQueueItem) {
        Task {
            await viewModel.playItem(item)
        }
    }
    
    private func handleRemoveItem(_ item: AudioQueueItem) {
        Task {
            await viewModel.removeItem(item)
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        Task {
            await viewModel.moveItems(from: source, to: destination)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        Task {
            await viewModel.deleteItems(at: offsets)
        }
    }
}

// MARK: - Queue Item Row

struct QueueItemRow: View {
    let item: AudioQueueItem
    let isReordering: Bool
    let onTap: () -> Void
    let onPlay: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // POI Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: poiIcon)
                        .font(.system(size: 20))
                        .foregroundColor(poiIconColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.poi.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Status Badge
                    statusBadge
                    
                    // Duration
                    if item.estimatedDuration > 0 {
                        Text(formatDuration(item.estimatedDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Download Status
                    downloadStatusIndicator
                }
            }
            
            Spacer()
            
            // Actions
            if !isReordering {
                HStack(spacing: 12) {
                    // Play Button
                    Button(action: onPlay) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .disabled(!item.isPlayable)
                    
                    // More Options
                    Menu {
                        Button("View Details", action: onTap)
                        Button("Remove from Queue", role: .destructive, action: onRemove)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReordering {
                onTap()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var statusBadge: some View {
        Text(item.status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(item.status.color)
            .cornerRadius(4)
    }
    
    private var downloadStatusIndicator: some View {
        Group {
            switch item.downloadStatus {
            case .notStarted:
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.gray)
            case .inProgress(let progress):
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(-90))
                }
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed(_):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .paused:
                Image(systemName: "pause.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }
    
    private var poiIcon: String {
        if item.poi.isVisited {
            return "checkmark.circle.fill"
        } else {
            return "mappin.circle"
        }
    }
    
    private var poiIconColor: Color {
        if item.poi.isVisited {
            return .green
        } else {
            return .blue
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, lineWidth: 3)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
    }
}

// MARK: - POI Detail Sheet

struct POIDetailSheet: View {
    let poi: PointOfInterest
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // POI Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(poi.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(poi.poiDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Location Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                    
                    Text("Coordinates: \(poi.latitude, specifier: "%.6f"), \(poi.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Radius: \(Int(poi.radius))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("POI Details")
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
}

#Preview {
    AudioQueueView()
        .environmentObject(AudioManager.shared)
}