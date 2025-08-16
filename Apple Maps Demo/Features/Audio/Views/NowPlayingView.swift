import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var hybridContentManager: HybridContentManager
    @State private var showingFullTranscript = false
    @State private var transcriptSearchText = ""
    @State private var showingContentSource = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let poi = audioManager.currentPOI {
                    // POI Header
                    poiHeaderSection(poi)
                    
                    // Content Source Indicator
                    contentSourceSection
                    
                    // Audio Information
                    audioInformationSection
                    
                    // Transcript Section
                    transcriptSection(poi)
                    
                    // Additional POI Details
                    poiDetailsSection(poi)
                } else {
                    // No Content State
                    noContentSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingFullTranscript) {
            fullTranscriptSheet
        }
        .sheet(isPresented: $showingContentSource) {
            contentSourceSheet
        }
    }
    
    // MARK: - POI Header Section
    
    private func poiHeaderSection(_ poi: PointOfInterest) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // POI Image and Basic Info
            HStack(spacing: 16) {
                // POI Thumbnail
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(poi.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if poi.isVisited {
                        Label("Visited", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Text("Order: \(poi.order + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // POI Description
            Text(poi.poiDescription)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Content Source Section
    
    private var contentSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content Source")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showingContentSource = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: contentSourceIcon)
                    .font(.system(size: 16))
                    .foregroundColor(contentSourceColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contentSourceTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(contentSourceDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                contentQualityBadge
            }
            .padding()
            .background(contentSourceColor.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Audio Information Section
    
    private var audioInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                audioInfoRow(title: "Duration", value: formatTime(audioManager.duration))
                audioInfoRow(title: "Progress", value: "\(Int(progressPercentage * 100))%")
                audioInfoRow(title: "Quality", value: audioManager.audioQuality.description)
                audioInfoRow(title: "Speed", value: String(format: "%.2g×", audioManager.playbackRate))
                
                if audioManager.isExternalAudioConnected {
                    audioInfoRow(title: "Output", value: "External Device")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func audioInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Transcript Section
    
    private func transcriptSection(_ poi: PointOfInterest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showingFullTranscript = true }) {
                    Text("View Full")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let transcript = getTranscriptForPOI(poi) {
                Text(transcript)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                
                if transcript.count > 200 {
                    Button(action: { showingFullTranscript = true }) {
                        Text("Read More...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Text("Transcript not available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - POI Details Section
    
    private func poiDetailsSection(_ poi: PointOfInterest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                detailRow(title: "Coordinates", value: String(format: "%.6f, %.6f", poi.latitude, poi.longitude))
                detailRow(title: "Radius", value: "\(Int(poi.radius))m")
                
                if let visitedAt = poi.visitedAt {
                    detailRow(title: "Visited At", value: formatDate(visitedAt))
                }
                
                if poi.triggerType == .beacon {
                    detailRow(title: "Beacon", value: "Enabled")
                }
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
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - No Content Section
    
    private var noContentSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Audio Playing")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Select a point of interest from the map to start listening to audio content.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Full Transcript Sheet
    
    private var fullTranscriptSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Search Bar
                SearchBar(text: $transcriptSearchText, placeholder: "Search transcript...")
                    .padding(.horizontal)
                
                // Transcript Content
                ScrollView {
                    if let poi = audioManager.currentPOI,
                       let transcript = getTranscriptForPOI(poi) {
                        Text(highlightedTranscript(transcript, searchTerm: transcriptSearchText))
                            .font(.body)
                            .lineSpacing(4)
                            .padding()
                    }
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFullTranscript = false
                    }
                }
            }
        }
    }
    
    // MARK: - Content Source Sheet
    
    private var contentSourceSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                contentSourceExplanation
                
                Spacer()
            }
            .padding()
            .navigationTitle("Content Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingContentSource = false
                    }
                }
            }
        }
    }
    
    private var contentSourceExplanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Types")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                sourceTypeRow(
                    icon: "network",
                    title: "Live AI Generated",
                    description: "Fresh content generated by AI based on current context and preferences",
                    color: .green
                )
                
                sourceTypeRow(
                    icon: "externaldrive.fill.badge.wifi",
                    title: "Cached AI Content",
                    description: "Previously generated AI content stored locally for offline access",
                    color: .orange
                )
                
                sourceTypeRow(
                    icon: "folder.fill",
                    title: "Local Content",
                    description: "Pre-recorded audio content included with the tour",
                    color: .blue
                )
            }
        }
    }
    
    private func sourceTypeRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Properties and Methods
    
    private var contentSourceIcon: String {
        switch hybridContentManager.currentContentSource {
        case .live: return "network"
        case .cached: return "externaldrive.fill.badge.wifi"
        case .local: return "folder.fill"
        }
    }
    
    private var contentSourceColor: Color {
        switch hybridContentManager.currentContentSource {
        case .live: return .green
        case .cached: return .orange
        case .local: return .blue
        }
    }
    
    private var contentSourceTitle: String {
        switch hybridContentManager.currentContentSource {
        case .live: return "Live AI Generated"
        case .cached: return "Cached AI Content"
        case .local: return "Local Content"
        }
    }
    
    private var contentSourceDescription: String {
        switch hybridContentManager.currentContentSource {
        case .live: return "Generated in real-time"
        case .cached: return "Previously generated"
        case .local: return "Pre-recorded audio"
        }
    }
    
    private var contentQualityBadge: some View {
        Text(audioManager.audioQuality.description)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(audioManager.audioQuality == .high ? .green : 
                       audioManager.audioQuality == .medium ? .orange : .red)
            .cornerRadius(12)
    }
    
    private var progressPercentage: Double {
        guard audioManager.duration > 0 else { return 0 }
        return audioManager.currentTime / audioManager.duration
    }
    
    private func getTranscriptForPOI(_ poi: PointOfInterest) -> String? {
        // This would typically fetch the transcript from the audio content
        // For now, return a placeholder
        return "This is a sample transcript for \(poi.name). In a real implementation, this would contain the actual transcript of the audio content being played."
    }
    
    private func highlightedTranscript(_ text: String, searchTerm: String) -> AttributedString {
        // For now, just return the text without highlighting
        // In a real implementation, this would properly highlight search terms
        return AttributedString(text)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Search Bar Component

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(AudioManager.shared)
        .environmentObject(HybridContentManager.shared)
}