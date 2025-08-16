import Foundation
import CoreLocation

enum Constants {
    enum Location {
        static let defaultRadius: CLLocationDistance = 50
        static let updateDistanceFilter: CLLocationDistance = 10
        static let minimumHorizontalAccuracy: CLLocationAccuracy = 100
        static let locationUpdateTimeout: TimeInterval = 10
    }
    
    enum Audio {
        static let defaultPlaybackRate: Float = 1.0
        static let skipInterval: TimeInterval = 30
        static let crossfadeDuration: TimeInterval = 0.5
        static let maxCacheSize: Int64 = 2_147_483_648 // 2GB
    }
    
    enum API {
        static let openAIBaseURL = "https://api.openai.com/v1"
        static let requestTimeout: TimeInterval = 30
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
    }
    
    enum UserDefaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastSelectedTourId = "lastSelectedTourId"
        static let preferredLanguage = "preferredLanguage"
        static let apiKey = "openai_api_key"
    }
    
    enum FileExtensions {
        static let audio = ["mp3", "m4a", "wav", "aac"]
        static let image = ["jpg", "jpeg", "png", "heic"]
    }
    
    enum Notifications {
        static let tourStarted = "tourStarted"
        static let tourCompleted = "tourCompleted"
        static let poiReached = "poiReached"
        static let connectivityChanged = "connectivityChanged"
    }
}