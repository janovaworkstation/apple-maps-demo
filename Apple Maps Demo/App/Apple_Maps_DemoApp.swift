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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Tour.self,
            PointOfInterest.self,
            AudioContent.self,
            UserPreferences.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(audioManager)
                .environmentObject(locationManager)
                .overlay(
                    QuickAccessOverlay()
                        .environmentObject(audioManager)
                )
        }
        .modelContainer(sharedModelContainer)
    }
}
