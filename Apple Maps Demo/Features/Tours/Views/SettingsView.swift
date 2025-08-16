import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = UserPreferencesViewModel()
    @State private var selectedTab = SettingsTab.general
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selection
                settingsTabBar
                
                // Content
                TabView(selection: $selectedTab) {
                    GeneralSettingsView(viewModel: viewModel)
                        .tag(SettingsTab.general)
                    
                    AudioSettingsView(viewModel: viewModel)
                        .tag(SettingsTab.audio)
                    
                    ContentSettingsView(viewModel: viewModel)
                        .tag(SettingsTab.content)
                    
                    APISettingsView(viewModel: viewModel)
                        .tag(SettingsTab.api)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadSettings()
            }
        }
    }
    
    // MARK: - Tab Bar
    
    private var settingsTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: UserPreferencesViewModel
    
    var body: some View {
        Form {
            Section("Language & Region") {
                Picker("Language", selection: $viewModel.preferredLanguage) {
                    ForEach(viewModel.availableLanguages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                
                Picker("Units", selection: $viewModel.unitSystem) {
                    Text("Metric").tag(UnitSystem.metric)
                    Text("Imperial").tag(UnitSystem.imperial)
                }
            }
            
            Section("Tour Behavior") {
                Toggle("Auto-play Audio", isOn: $viewModel.autoplayEnabled)
                
                Toggle("Background Location", isOn: $viewModel.backgroundLocationEnabled)
                
                Picker("Notification Style", selection: $viewModel.notificationStyle) {
                    Text("None").tag(NotificationStyle.none)
                    Text("Banner").tag(NotificationStyle.banner)
                    Text("Sound").tag(NotificationStyle.sound)
                    Text("Both").tag(NotificationStyle.both)
                }
            }
            
            Section("Accessibility") {
                Toggle("Large Text", isOn: $viewModel.largeTextEnabled)
                
                Toggle("High Contrast", isOn: $viewModel.highContrastEnabled)
                
                Toggle("Reduce Motion", isOn: $viewModel.reduceMotionEnabled)
            }
            
            Section("Privacy") {
                Toggle("Share Analytics", isOn: $viewModel.analyticsEnabled)
                
                Toggle("Crash Reporting", isOn: $viewModel.crashReportingEnabled)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Audio Settings View

struct AudioSettingsView: View {
    @ObservedObject var viewModel: UserPreferencesViewModel
    
    var body: some View {
        Form {
            Section("Voice & Speech") {
                Picker("Voice Type", selection: $viewModel.voiceType) {
                    Text("Natural").tag(VoiceType.natural)
                    Text("Enhanced").tag(VoiceType.enhanced)
                    Text("Compact").tag(VoiceType.compact)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playback Speed")
                    
                    HStack {
                        Text("0.5×")
                            .font(.caption)
                        
                        Slider(value: $viewModel.playbackSpeed, in: 0.5...2.0, step: 0.25)
                        
                        Text("2.0×")
                            .font(.caption)
                    }
                    
                    Text("\(viewModel.playbackSpeed, specifier: "%.2g")× Normal Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Audio Quality") {
                Picker("Preferred Quality", selection: $viewModel.preferredAudioQuality) {
                    Text("Low (Faster)").tag(AudioQuality.low)
                    Text("Medium").tag(AudioQuality.medium)
                    Text("High (Best)").tag(AudioQuality.high)
                }
                
                Toggle("Enhance for Car Audio", isOn: $viewModel.carAudioOptimization)
                
                Toggle("Normalize Volume", isOn: $viewModel.volumeNormalization)
            }
            
            Section("Audio Output") {
                Picker("Output Route", selection: $viewModel.preferredAudioRoute) {
                    Text("Automatic").tag(SettingsAudioRoute.automatic)
                    Text("Built-in Speaker").tag(SettingsAudioRoute.builtin)
                    Text("Bluetooth").tag(SettingsAudioRoute.bluetooth)
                    Text("AirPlay").tag(SettingsAudioRoute.airplay)
                }
                
                Toggle("Duck Other Audio", isOn: $viewModel.duckOtherAudio)
            }
            
            Section("Volume") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Volume")
                    
                    HStack {
                        Image(systemName: "speaker.1.fill")
                            .foregroundColor(.gray)
                        
                        Slider(value: $viewModel.defaultVolume, in: 0...1)
                        
                        Image(systemName: "speaker.3.fill")
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(Int(viewModel.defaultVolume * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Content Settings View

struct ContentSettingsView: View {
    @ObservedObject var viewModel: UserPreferencesViewModel
    @State private var showingClearCacheAlert = false
    
    var body: some View {
        Form {
            Section("Offline Content") {
                Toggle("Download Tours Automatically", isOn: $viewModel.autoDownloadTours)
                
                Toggle("Download on WiFi Only", isOn: $viewModel.wifiOnlyDownloads)
                
                Picker("Download Quality", selection: $viewModel.downloadQuality) {
                    Text("Standard").tag(AudioQuality.medium)
                    Text("High Quality").tag(AudioQuality.high)
                }
            }
            
            Section("Storage Management") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(viewModel.cacheSize)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Downloaded Tours")
                    Spacer()
                    Text("\(viewModel.downloadedToursCount)")
                        .foregroundColor(.secondary)
                }
                
                Button("Clear Cache") {
                    showingClearCacheAlert = true
                }
                .foregroundColor(.red)
            }
            
            Section("Content Generation") {
                Toggle("Use AI Content", isOn: $viewModel.aiContentEnabled)
                
                Picker("Content Style", selection: $viewModel.contentStyle) {
                    Text("Informative").tag(ContentStyle.informative)
                    Text("Conversational").tag(ContentStyle.conversational)
                    Text("Educational").tag(ContentStyle.educational)
                    Text("Entertainment").tag(ContentStyle.entertainment)
                }
                
                Picker("Detail Level", selection: $viewModel.detailLevel) {
                    Text("Brief").tag(DetailLevel.brief)
                    Text("Standard").tag(DetailLevel.standard)
                    Text("Detailed").tag(DetailLevel.detailed)
                }
            }
            
            Section("Personalization") {
                Toggle("Adaptive Content", isOn: $viewModel.adaptiveContent)
                
                MultiSelector(
                    title: "Interests",
                    options: viewModel.availableInterests,
                    selections: $viewModel.selectedInterests
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearCache()
            }
        } message: {
            Text("This will remove all cached audio files and downloaded content. Tours will need to be downloaded again.")
        }
    }
}

// MARK: - API Settings View

struct APISettingsView: View {
    @ObservedObject var viewModel: UserPreferencesViewModel
    @State private var showingAPIKeyHelp = false
    
    var body: some View {
        Form {
            Section(header: HStack {
                Text("OpenAI Configuration")
                Spacer()
                Button("Help") {
                    showingAPIKeyHelp = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                SecureField("API Key", text: $viewModel.openAIAPIKey)
                    .textContentType(.password)
                
                Picker("Model", selection: $viewModel.openAIModel) {
                    Text("GPT-4").tag("gpt-4")
                    Text("GPT-4 Turbo").tag("gpt-4-turbo")
                    Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                }
                
                Picker("Voice Model", selection: $viewModel.ttsModel) {
                    Text("TTS-1").tag("tts-1")
                    Text("TTS-1 HD").tag("tts-1-hd")
                }
            }
            
            Section("Request Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request Timeout")
                    
                    HStack {
                        Text("10s")
                            .font(.caption)
                        
                        Slider(value: $viewModel.requestTimeout, in: 10...60, step: 5)
                        
                        Text("60s")
                            .font(.caption)
                    }
                    
                    Text("\(Int(viewModel.requestTimeout)) seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Retries")
                    
                    Stepper(value: $viewModel.maxRetries, in: 0...5) {
                        Text("\(viewModel.maxRetries) attempts")
                    }
                }
            }
            
            Section("Usage & Billing") {
                HStack {
                    Text("Estimated Monthly Cost")
                    Spacer()
                    Text(viewModel.estimatedMonthlyCost)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Requests This Month")
                    Spacer()
                    Text("\(viewModel.requestsThisMonth)")
                        .foregroundColor(.secondary)
                }
                
                Button("View Detailed Usage") {
                    viewModel.showUsageStatistics()
                }
            }
            
            Section("Data & Privacy") {
                Toggle("Cache API Responses", isOn: $viewModel.cacheAPIResponses)
                
                Toggle("Use for Training", isOn: $viewModel.allowTrainingData)
                    .disabled(true) // OpenAI doesn't use API data for training
                
                Text("OpenAI does not use API data for training models.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingAPIKeyHelp) {
            APIKeyHelpView()
        }
    }
}

// MARK: - Multi Selector Component

struct MultiSelector: View {
    let title: String
    let options: [String]
    @Binding var selections: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        if selections.contains(option) {
                            selections.remove(option)
                        } else {
                            selections.insert(option)
                        }
                    }) {
                        Text(option)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selections.contains(option) ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selections.contains(option) ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
        }
    }
}

// MARK: - API Key Help View

struct APIKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Getting Your OpenAI API Key")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        helpStep(number: 1, title: "Visit OpenAI Platform", description: "Go to platform.openai.com and sign in to your account")
                        
                        helpStep(number: 2, title: "Navigate to API Keys", description: "Click on your profile → View API keys")
                        
                        helpStep(number: 3, title: "Create New Key", description: "Click 'Create new secret key' and give it a name")
                        
                        helpStep(number: 4, title: "Copy & Paste", description: "Copy the generated key and paste it into the API Key field above")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important Notes")
                            .font(.headline)
                        
                        Text("• Keep your API key secure and never share it publicly")
                        Text("• API usage is billed per request to your OpenAI account")
                        Text("• You can monitor usage in your OpenAI dashboard")
                        Text("• The app works offline with cached content if no API key is provided")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("API Key Help")
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
    
    private func helpStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
    case general = "general"
    case audio = "audio"
    case content = "content"
    case api = "api"
    
    var title: String {
        switch self {
        case .general: return "General"
        case .audio: return "Audio"
        case .content: return "Content"
        case .api: return "API"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .audio: return "speaker.wave.3"
        case .content: return "square.and.arrow.down"
        case .api: return "key"
        }
    }
}

#Preview {
    SettingsView()
}