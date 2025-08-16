import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    @EnvironmentObject var audioManager: AudioManager
    @State private var isDragging = false
    @State private var tempProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Now Playing Info
            if let poi = audioManager.currentPOI {
                VStack(spacing: 12) {
                    // POI Image Placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                        )
                    
                    // POI Information
                    VStack(spacing: 4) {
                        Text(poi.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text(poi.poiDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal)
                }
            }
            
            // Progress and Time
            VStack(spacing: 8) {
                // Progress Slider
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * currentProgress, height: 4)
                        
                        // Thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .shadow(radius: 2)
                            .offset(x: geometry.size.width * currentProgress - 10)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let progress = min(max(0, (value.location.x) / geometry.size.width), 1)
                                        tempProgress = progress
                                        isDragging = true
                                    }
                                    .onEnded { _ in
                                        let newTime = tempProgress * audioManager.duration
                                        Task {
                                            await viewModel.seekToTime(newTime)
                                        }
                                        isDragging = false
                                    }
                            )
                    }
                }
                .frame(height: 20)
                .padding(.horizontal)
                
                // Time Labels
                HStack {
                    Text(formatTime(isDragging ? tempProgress * audioManager.duration : audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(audioManager.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal)
            }
            
            // Main Controls
            HStack(spacing: 40) {
                // Skip Backward
                Button(action: { Task { await viewModel.skipBackward() } }) {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                .disabled(audioManager.currentTime < 30)
                
                // Play/Pause
                Button(action: { Task { await viewModel.togglePlayback() } }) {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
                .disabled(audioManager.currentPOI == nil)
                
                // Skip Forward
                Button(action: { Task { await viewModel.skipForward() } }) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                .disabled(audioManager.currentTime + 30 > audioManager.duration)
            }
            
            // Secondary Controls
            HStack(spacing: 30) {
                // Playback Speed
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button(action: { Task { await viewModel.setPlaybackSpeed(Float(speed)) } }) {
                            HStack {
                                Text("\(speed, specifier: "%.2g")×")
                                if audioManager.playbackRate == Float(speed) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 16))
                        Text("\(audioManager.playbackRate, specifier: "%.2g")×")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Volume Control
                HStack(spacing: 8) {
                    Image(systemName: audioManager.volume < 0.1 ? "speaker.slash.fill" : 
                                      audioManager.volume < 0.5 ? "speaker.1.fill" : "speaker.3.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { Double(audioManager.volume) },
                        set: { value in
                            Task {
                                await viewModel.setVolume(Float(value))
                            }
                        }
                    ), in: 0...1)
                    .frame(width: 80)
                    .accentColor(.blue)
                }
                
                // Audio Quality Indicator
                HStack(spacing: 4) {
                    Image(systemName: audioQualityIcon)
                        .font(.system(size: 16))
                        .foregroundColor(audioQualityColor)
                    
                    Text(audioManager.audioQuality.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Status Indicators
            if audioManager.isBuffering {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Buffering...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            if audioManager.isCrossfading {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Crossfading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        .onAppear {
            viewModel.setupAudioManager(audioManager)
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentProgress: Double {
        guard audioManager.duration > 0 else { return 0 }
        if isDragging {
            return tempProgress
        }
        return audioManager.currentTime / audioManager.duration
    }
    
    private var audioQualityIcon: String {
        switch audioManager.audioQuality {
        case .low: return "wifi.slash"
        case .medium: return "wifi"
        case .high: return "wifi.circle.fill"
        case .lossless: return "wifi.circle.fill"
        }
    }
    
    private var audioQualityColor: Color {
        switch audioManager.audioQuality {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        case .lossless: return .blue
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Quality Extension
// Note: AudioQuality already has a description property

#Preview {
    AudioPlayerView()
        .environmentObject(AudioManager.shared)
        .padding()
}