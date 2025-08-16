import Foundation
import SwiftData
import SwiftUI

// MARK: - DataManager Protocol

protocol DataManagerProtocol {
    // CRUD Operations
    func save<T: PersistentModel>(_ object: T) async throws
    func fetch<T: PersistentModel>(_ type: T.Type) async throws -> [T]
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T]
    func fetchFirst<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> T?
    func delete<T: PersistentModel>(_ object: T) async throws
    func deleteAll<T: PersistentModel>(_ type: T.Type) async throws
    
    // Batch Operations
    func saveBatch<T: PersistentModel>(_ objects: [T]) async -> BatchOperationResult
    func deleteBatch<T: PersistentModel>(_ objects: [T]) async -> BatchOperationResult
    
    // Validation
    func validate<T: PersistentModel>(_ object: T) -> ValidationResult
    
    // Context Management
    func performBackgroundTask(_ block: @escaping (ModelContext) -> Void) async
}

// MARK: - SwiftData Manager Implementation

class DataManager: DataManagerProtocol, ObservableObject {
    static let shared: DataManager = {
        MainActor.assumeIsolated {
            DataManager()
        }
    }()
    
    private let modelContainer: ModelContainer
    private let mainContext: ModelContext
    
    @Published var isLoading = false
    @Published var lastError: DataError?
    
    @MainActor private init() {
        let schema = Schema([
            Tour.self,
            PointOfInterest.self,
            AudioContent.self,
            UserPreferences.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
            // Store a reference that will be accessed only from MainActor
            self.mainContext = container.mainContext
        } catch {
            fatalError("Failed to initialize DataManager: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    @MainActor
    func save<T: PersistentModel>(_ object: T) async throws {
        do {
            let validationResult = validate(object)
            guard validationResult.isValid else {
                throw DataError.validationFailed(validationResult.errors.joined(separator: ", "))
            }
            
            mainContext.insert(object)
            try mainContext.save()
        } catch let error as DataError {
            lastError = error
            throw error
        } catch {
            let dataError = DataError.saveFailed(error)
            lastError = dataError
            throw dataError
        }
    }
    
    func fetch<T: PersistentModel>(_ type: T.Type) async throws -> [T] {
        return try await fetch(type, predicate: nil)
    }
    
    @MainActor
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T] {
        do {
            let descriptor = FetchDescriptor<T>(predicate: predicate)
            return try mainContext.fetch(descriptor)
        } catch {
            let dataError = DataError.fetchFailed(error)
            lastError = dataError
            throw dataError
        }
    }
    
    @MainActor
    func fetchFirst<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> T? {
        do {
            var descriptor = FetchDescriptor<T>(predicate: predicate)
            descriptor.fetchLimit = 1
            let results = try mainContext.fetch(descriptor)
            return results.first
        } catch {
            let dataError = DataError.fetchFailed(error)
            lastError = dataError
            throw dataError
        }
    }
    
    @MainActor
    func delete<T: PersistentModel>(_ object: T) async throws {
        do {
            mainContext.delete(object)
            try mainContext.save()
        } catch {
            let dataError = DataError.deleteFailed(error)
            lastError = dataError
            throw dataError
        }
    }
    
    @MainActor
    func deleteAll<T: PersistentModel>(_ type: T.Type) async throws {
        do {
            let objects = try await fetch(type)
            for object in objects {
                mainContext.delete(object)
            }
            try mainContext.save()
        } catch {
            let dataError = DataError.deleteFailed(error)
            lastError = dataError
            throw dataError
        }
    }
    
    // MARK: - Batch Operations
    
    func saveBatch<T: PersistentModel>(_ objects: [T]) async -> BatchOperationResult {
        var successCount = 0
        var errors: [DataError] = []
        
        await performBackgroundTask { context in
            for object in objects {
                do {
                    let validationResult = self.validate(object)
                    guard validationResult.isValid else {
                        errors.append(.validationFailed(validationResult.errors.joined(separator: ", ")))
                        continue
                    }
                    
                    context.insert(object)
                    try context.save()
                    successCount += 1
                } catch {
                    errors.append(.saveFailed(error))
                }
            }
        }
        
        return BatchOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    func deleteBatch<T: PersistentModel>(_ objects: [T]) async -> BatchOperationResult {
        var successCount = 0
        var errors: [DataError] = []
        
        await performBackgroundTask { context in
            for object in objects {
                do {
                    context.delete(object)
                    try context.save()
                    successCount += 1
                } catch {
                    errors.append(.deleteFailed(error))
                }
            }
        }
        
        return BatchOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Validation
    
    func validate<T: PersistentModel>(_ object: T) -> ValidationResult {
        var errors: [String] = []
        
        // Type-specific validation
        switch object {
        case let tour as Tour:
            do {
                try tour.validate()
            } catch {
                errors.append(error.localizedDescription)
            }
            
        case let poi as PointOfInterest:
            do {
                try poi.validate()
            } catch {
                errors.append(error.localizedDescription)
            }
            
        case let audioContent as AudioContent:
            do {
                try audioContent.validateContent()
            } catch {
                errors.append(error.localizedDescription)
            }
            
        default:
            break
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
    
    // MARK: - Context Management
    
    func performBackgroundTask(_ block: @escaping (ModelContext) -> Void) async {
        await withCheckedContinuation { continuation in
            Task.detached {
                let backgroundContext = ModelContext(self.modelContainer)
                block(backgroundContext)
                continuation.resume()
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func count<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>? = nil) async throws -> Int {
        let objects = try await fetch(type, predicate: predicate)
        return objects.count
    }
    
    func exists<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) async throws -> Bool {
        let object = try await fetchFirst(type, predicate: predicate)
        return object != nil
    }
    
    func refresh() throws {
        try mainContext.save()
    }
    
    func reset() {
        mainContext.rollback()
    }
    
    // MARK: - Error Handling
    
    func clearLastError() {
        lastError = nil
    }
    
    func handleError(_ error: Error) {
        if let dataError = error as? DataError {
            lastError = dataError
        } else {
            lastError = DataError.repositoryError(error.localizedDescription)
        }
    }
}

// MARK: - DataManager Extensions for Specific Operations

extension DataManager {
    // MARK: - Tour Operations
    
    func fetchTours(category: TourCategory? = nil) async throws -> [Tour] {
        if let category = category {
            let predicate = #Predicate<Tour> { tour in
                tour.category == category
            }
            return try await fetch(Tour.self, predicate: predicate)
        } else {
            return try await fetch(Tour.self)
        }
    }
    
    func fetchDownloadedTours() async throws -> [Tour] {
        let predicate = #Predicate<Tour> { tour in
            tour.isDownloaded == true
        }
        return try await fetch(Tour.self, predicate: predicate)
    }
    
    // MARK: - POI Operations
    
    func fetchPOIs(for tourId: UUID) async throws -> [PointOfInterest] {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.tourId == tourId
        }
        return try await fetch(PointOfInterest.self, predicate: predicate)
    }
    
    func fetchVisitedPOIs() async throws -> [PointOfInterest] {
        let predicate = #Predicate<PointOfInterest> { poi in
            poi.isVisited == true
        }
        return try await fetch(PointOfInterest.self, predicate: predicate)
    }
    
    // MARK: - Audio Content Operations
    
    func fetchAudioContent(for poiId: UUID) async throws -> AudioContent? {
        let predicate = #Predicate<AudioContent> { content in
            content.poiId == poiId
        }
        return try await fetchFirst(AudioContent.self, predicate: predicate)
    }
    
    func fetchDownloadedAudioContent() async throws -> [AudioContent] {
        // SwiftData predicates don't handle enum cases well, so fetch all and filter in memory
        let allContent = try await fetch(AudioContent.self)
        return allContent.filter { content in
            if case .completed = content.downloadStatus {
                return true
            }
            return false
        }
    }
    
    // MARK: - User Preferences Operations
    
    func fetchUserPreferences() async throws -> UserPreferences {
        if let preferences = try await fetchFirst(UserPreferences.self, predicate: nil) {
            return preferences
        } else {
            // Create default preferences if none exist
            let defaultPreferences = UserPreferences()
            try await save(defaultPreferences)
            return defaultPreferences
        }
    }
}

// MARK: - SwiftUI Environment

struct DataManagerKey: EnvironmentKey {
    static let defaultValue: DataManager = DataManager.shared
}

extension EnvironmentValues {
    var dataManager: DataManager {
        get { self[DataManagerKey.self] }
        set { self[DataManagerKey.self] = newValue }
    }
}