import SwiftUI

struct MainTabView: View {
    @StateObject private var hybridContentManager = HybridContentManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Map Tab
            TourMapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(0)
            
            // Tours Tab
            TourListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tours")
                }
                .tag(1)
            
            // Audio Player Tab
            AudioPlayerTabView()
                .tabItem {
                    Image(systemName: "play.circle")
                    Text("Player")
                }
                .tag(2)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .environmentObject(hybridContentManager)
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        // Customize tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Audio Player Tab View

struct AudioPlayerTabView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var hybridContentManager: HybridContentManager
    @State private var selectedSegment = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Audio Tabs", selection: $selectedSegment) {
                    Text("Player").tag(0)
                    Text("Now Playing").tag(1)
                    Text("Queue").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedSegment) {
                    // Audio Player
                    ScrollView {
                        AudioPlayerView()
                            .padding()
                    }
                    .tag(0)
                    
                    // Now Playing Info
                    NowPlayingView()
                        .tag(1)
                    
                    // Audio Queue
                    AudioQueueView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Quick Access Overlay

struct QuickAccessOverlay: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var showingMiniPlayer = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack {
            Spacer()
            
            if audioManager.isPlaying && audioManager.currentPOI != nil && !showingMiniPlayer {
                // Mini Player
                HStack(spacing: 12) {
                    // POI Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioManager.currentPOI?.name ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text("Now Playing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Play/Pause Button
                    Button(action: { 
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.resume()
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    
                    // Close Button
                    Button(action: { 
                        audioManager.stop()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 8)
                .padding(.horizontal)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 50 {
                                // Dismiss mini player if dragged up/down significantly
                                withAnimation {
                                    showingMiniPlayer = true
                                }
                            }
                            dragOffset = .zero
                        }
                )
                .onTapGesture {
                    showingMiniPlayer = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: audioManager.isPlaying)
            }
        }
        .sheet(isPresented: $showingMiniPlayer) {
            AudioPlayerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - App State Manager

@MainActor
class AppStateManager: ObservableObject {
    @Published var selectedTab = 0
    @Published var isShowingTourDetail = false
    @Published var selectedTour: Tour?
    @Published var isShowingAudioPlayer = false
    
    static let shared = AppStateManager()
    
    private init() {}
    
    func showTourDetail(_ tour: Tour) {
        selectedTour = tour
        isShowingTourDetail = true
    }
    
    func showAudioPlayer() {
        selectedTab = 2
        isShowingAudioPlayer = true
    }
    
    func navigateToMap() {
        selectedTab = 0
    }
    
    func navigateToTours() {
        selectedTab = 1
    }
}

#Preview {
    MainTabView()
        .environmentObject(AudioManager.shared)
        .environmentObject(LocationManager.shared)
}