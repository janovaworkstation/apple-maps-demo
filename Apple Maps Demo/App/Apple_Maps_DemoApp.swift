//
//  Apple_Maps_DemoApp.swift
//  Apple Maps Demo
//
//  Created by Jeff Lusenhop on 8/16/25.
//

import SwiftUI
import SwiftData
import CarPlay

@main
struct Apple_Maps_DemoApp: App {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var appStateManager = AppStateManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Tour.self,
            PointOfInterest.self,
            AudioContent.self,
            UserPreferences.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("📊 SwiftData ModelContainer initialized successfully")
            return container
        } catch {
            print("💥 SwiftData ModelContainer initialization failed: \(error)")
            print("🔄 Attempting fallback to in-memory storage...")
            
            // Fallback to in-memory storage if persistent storage fails
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                print("✅ Fallback in-memory ModelContainer created successfully")
                return fallbackContainer
            } catch {
                fatalError("Could not create ModelContainer even with in-memory fallback: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(audioManager)
                .environmentObject(locationManager)
                .environmentObject(appStateManager)
                .overlay(
                    QuickAccessOverlay()
                        .environmentObject(audioManager)
                )
        }
        .modelContainer(sharedModelContainer)
    }
}
