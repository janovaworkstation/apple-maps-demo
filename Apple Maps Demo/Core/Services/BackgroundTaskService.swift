import Foundation
import BackgroundTasks
import UIKit
import CoreLocation

// MARK: - BackgroundTaskService Protocol

protocol BackgroundTaskServiceProtocol {
    // Task Registration & Scheduling
    func registerBackgroundTasks()
    func scheduleBackgroundTasks()
    func cancelAllBackgroundTasks()
    
    // Location Processing
    func handleBackgroundLocationUpdate(_ location: CLLocation) async
    func handleBackgroundRegionEvent(_ event: RegionEvent) async
    
    // Status & Monitoring
    func getBackgroundTaskStatus() -> BackgroundTaskStatus
}

// MARK: - BackgroundTaskService Implementation

class BackgroundTaskService: BackgroundTaskServiceProtocol, ObservableObject {
    static let shared = BackgroundTaskService()
    
    // MARK: - Background Task Identifiers
    private enum TaskIdentifier {
        static let locationProcessing = "com.jlusenhop.applemapsdemo.location-processing"
        static let visitValidation = "com.jlusenhop.applemapsdemo.visit-validation"
        static let dataSync = "com.jlusenhop.applemapsdemo.data-sync"
    }
    
    // MARK: - Dependencies
    private let geofenceService: GeofenceService
    private let visitTrackingService: VisitTrackingService
    private let dataService: DataService
    
    // MARK: - State
    @Published private(set) var backgroundTaskStatus: BackgroundTaskStatus = .inactive
    @Published private(set) var lastBackgroundProcessing: Date?
    
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var processingQueue = DispatchQueue(label: "background-processing", qos: .utility)
    
    // MARK: - Initialization
    
    private init(
        geofenceService: GeofenceService? = nil,
        visitTrackingService: VisitTrackingService? = nil,
        dataService: DataService? = nil
    ) {
        self.geofenceService = geofenceService ?? MainActor.assumeIsolated { GeofenceService.shared }
        self.visitTrackingService = visitTrackingService ?? MainActor.assumeIsolated { VisitTrackingService.shared }
        self.dataService = dataService ?? MainActor.assumeIsolated { DataService.shared }
        
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    // MARK: - Task Registration & Scheduling
    
    func registerBackgroundTasks() {
        print("📋 Registering background tasks")
        
        // Register location processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.locationProcessing,
            using: processingQueue
        ) { [weak self] task in
            self?.handleLocationProcessingTask(task as! BGProcessingTask)
        }
        
        // Register visit validation task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.visitValidation,
            using: processingQueue
        ) { [weak self] task in
            self?.handleVisitValidationTask(task as! BGProcessingTask)
        }
        
        // Register data sync task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.dataSync,
            using: processingQueue
        ) { [weak self] task in
            self?.handleDataSyncTask(task as! BGProcessingTask)
        }
        
        print("✅ Background tasks registered")
    }
    
    func scheduleBackgroundTasks() {
        print("⏰ Scheduling background tasks")
        
        scheduleLocationProcessingTask()
        scheduleVisitValidationTask()
        scheduleDataSyncTask()
    }
    
    func cancelAllBackgroundTasks() {
        print("🚫 Cancelling all background tasks")
        
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: TaskIdentifier.locationProcessing)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: TaskIdentifier.visitValidation)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: TaskIdentifier.dataSync)
        
        backgroundTaskStatus = .inactive
    }
    
    // MARK: - Background Task Handlers
    
    private func handleLocationProcessingTask(_ task: BGProcessingTask) {
        print("🌍 Handling background location processing task")
        
        backgroundTaskStatus = .locationProcessing
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = LocationProcessingOperation(
            geofenceService: geofenceService,
            visitTrackingService: visitTrackingService
        )
        
        task.expirationHandler = {
            print("⏰ Background location processing task expired")
            queue.cancelAllOperations()
            self.backgroundTaskStatus = .expired
        }
        
        operation.completionBlock = {
            print("✅ Background location processing completed")
            self.lastBackgroundProcessing = Date()
            self.backgroundTaskStatus = .completed
            task.setTaskCompleted(success: !operation.isCancelled)
            
            // Schedule next task
            self.scheduleLocationProcessingTask()
        }
        
        queue.addOperation(operation)
    }
    
    private func handleVisitValidationTask(_ task: BGProcessingTask) {
        print("✅ Handling background visit validation task")
        
        backgroundTaskStatus = .visitValidation
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = VisitValidationOperation(
            visitTrackingService: visitTrackingService
        )
        
        task.expirationHandler = {
            print("⏰ Background visit validation task expired")
            queue.cancelAllOperations()
            self.backgroundTaskStatus = .expired
        }
        
        operation.completionBlock = {
            print("✅ Background visit validation completed")
            self.backgroundTaskStatus = .completed
            task.setTaskCompleted(success: !operation.isCancelled)
            
            // Schedule next task
            self.scheduleVisitValidationTask()
        }
        
        queue.addOperation(operation)
    }
    
    private func handleDataSyncTask(_ task: BGProcessingTask) {
        print("💾 Handling background data sync task")
        
        backgroundTaskStatus = .dataSync
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = DataSyncOperation(
            dataService: dataService
        )
        
        task.expirationHandler = {
            print("⏰ Background data sync task expired")
            queue.cancelAllOperations()
            self.backgroundTaskStatus = .expired
        }
        
        operation.completionBlock = {
            print("✅ Background data sync completed")
            self.backgroundTaskStatus = .completed
            task.setTaskCompleted(success: !operation.isCancelled)
            
            // Schedule next task
            self.scheduleDataSyncTask()
        }
        
        queue.addOperation(operation)
    }
    
    // MARK: - Task Scheduling
    
    private func scheduleLocationProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.locationProcessing)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📍 Location processing task scheduled")
        } catch {
            print("❌ Failed to schedule location processing task: \(error)")
        }
    }
    
    private func scheduleVisitValidationTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.visitValidation)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Visit validation task scheduled")
        } catch {
            print("❌ Failed to schedule visit validation task: \(error)")
        }
    }
    
    private func scheduleDataSyncTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.dataSync)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("💾 Data sync task scheduled")
        } catch {
            print("❌ Failed to schedule data sync task: \(error)")
        }
    }
    
    // MARK: - Location Processing
    
    @MainActor
    func handleBackgroundLocationUpdate(_ location: CLLocation) async {
        print("📍 Processing background location update: \(location.coordinate)")
        
        // Start background task with timeout protection
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "LocationUpdate") {
            print("⏰ Background location update task expired")
        }
        
        defer {
            if taskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            }
        }
        
        // Set a maximum processing time of 25 seconds (well under the 30-second limit)
        let maxProcessingTime: TimeInterval = 25.0
        let startTime = Date()
        
        do {
            // Quick timeout check
            guard Date().timeIntervalSince(startTime) < maxProcessingTime else {
                print("⏰ Background location processing timeout, aborting")
                return
            }
            
            // Update geofence monitoring based on new location
            try await geofenceService.updateMonitoredRegions(userLocation: location)
            
            // Quick timeout check
            guard Date().timeIntervalSince(startTime) < maxProcessingTime else {
                print("⏰ Background location processing timeout after geofence update")
                return
            }
            
            // Validate any ongoing visit sessions
            if let session = visitTrackingService.getCurrentVisitSession() {
                let validation = await visitTrackingService.validateVisit(for: session.poi, userLocation: location)
                
                if !validation.isValid {
                    print("⚠️ Background validation failed, ending session: \(validation.reason)")
                    try await visitTrackingService.endVisitSession(for: session.poi)
                }
            }
            
            lastBackgroundProcessing = Date()
            print("✅ Background location update completed in \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s")
            
        } catch {
            print("❌ Background location processing failed: \(error)")
        }
    }
    
    @MainActor
    func handleBackgroundRegionEvent(_ event: RegionEvent) async {
        print("🚨 Processing background region event: \(event.type) for \(event.poi.name)")
        
        // Start background task with timeout protection
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "RegionEvent") {
            print("⏰ Background region event task expired")
        }
        
        defer {
            if taskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            }
        }
        
        // Set a maximum processing time of 25 seconds (well under the 30-second limit)
        let maxProcessingTime: TimeInterval = 25.0
        let startTime = Date()
        
        do {
            // Quick timeout check
            guard Date().timeIntervalSince(startTime) < maxProcessingTime else {
                print("⏰ Background region event processing timeout, aborting")
                return
            }
            
            switch event.type {
            case .entry:
                // Start visit session if user enters POI region
                if let userLocation = event.userLocation {
                    try await visitTrackingService.startVisitSession(for: event.poi, userLocation: userLocation)
                }
                
            case .exit:
                // End visit session if user exits POI region
                if visitTrackingService.getCurrentVisitSession()?.poi.id == event.poi.id {
                    try await visitTrackingService.endVisitSession(for: event.poi)
                }
            }
            
            print("✅ Background region event completed in \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s")
            
        } catch {
            print("❌ Background region event processing failed: \(error)")
        }
    }
    
    // MARK: - Status & Monitoring
    
    func getBackgroundTaskStatus() -> BackgroundTaskStatus {
        return backgroundTaskStatus
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        // Ensure previous task is ended before starting new one
        endBackgroundTask()
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "LocationProcessing") { [weak self] in
            print("⏰ Background task expired, ending automatically")
            self?.endBackgroundTask()
        }
        
        if backgroundTaskIdentifier == .invalid {
            print("❌ Failed to create background task")
        } else {
            print("✅ Background task started: \(backgroundTaskIdentifier.rawValue)")
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            print("🏁 Ending background task: \(backgroundTaskIdentifier.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background, scheduling background tasks")
        scheduleBackgroundTasks()
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground")
        backgroundTaskStatus = .inactive
    }
}

// MARK: - Background Operations

private class LocationProcessingOperation: Operation, @unchecked Sendable {
    private let geofenceService: GeofenceService
    private let visitTrackingService: VisitTrackingService
    
    init(geofenceService: GeofenceService, visitTrackingService: VisitTrackingService) {
        self.geofenceService = geofenceService
        self.visitTrackingService = visitTrackingService
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        print("🔄 Executing location processing operation")
        
        // Perform location-based updates
        Task {
            // Update geofence monitoring if needed
            let statistics = await geofenceService.getGeofenceStatistics()
            print("📊 Geofence statistics: \(statistics.totalMonitoredRegions) regions monitored")
        }
    }
}

private class VisitValidationOperation: Operation, @unchecked Sendable {
    private let visitTrackingService: VisitTrackingService
    
    init(visitTrackingService: VisitTrackingService) {
        self.visitTrackingService = visitTrackingService
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        print("🔄 Executing visit validation operation")
        
        // Validate ongoing visit sessions
        Task {
            if let session = await visitTrackingService.getCurrentVisitSession() {
                print("📍 Validating ongoing visit session for: \(session.poi.name)")
                
                // Additional validation logic could be added here
                let progress = session.calculateProgress()
                print("⏱️ Visit progress: \(Int(progress.percentage))%")
            }
        }
    }
}

private class DataSyncOperation: Operation, @unchecked Sendable {
    private let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        print("🔄 Executing data sync operation")
        
        // Perform data maintenance and sync
        Task {
            do {
                try await dataService.performMaintenance()
                print("🧹 Data maintenance completed")
            } catch {
                print("❌ Data maintenance failed: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

enum BackgroundTaskStatus {
    case inactive
    case locationProcessing
    case visitValidation
    case dataSync
    case completed
    case expired
    case failed(Error)
    
    var description: String {
        switch self {
        case .inactive:
            return "Inactive"
        case .locationProcessing:
            return "Processing Location"
        case .visitValidation:
            return "Validating Visits"
        case .dataSync:
            return "Syncing Data"
        case .completed:
            return "Completed"
        case .expired:
            return "Expired"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .locationProcessing, .visitValidation, .dataSync:
            return true
        default:
            return false
        }
    }
}