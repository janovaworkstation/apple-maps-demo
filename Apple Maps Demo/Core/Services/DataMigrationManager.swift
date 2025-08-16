import Foundation
import SwiftData

// MARK: - Migration Manager Protocol

protocol DataMigrationManagerProtocol {
    func performMigration() async throws
    func getCurrentSchemaVersion() async throws -> String
    func needsMigration() async throws -> Bool
    func getMigrationPlan() async throws -> MigrationPlan
    func performBackup() async throws -> URL
    func restoreFromBackup(_ backupURL: URL) async throws
}

// MARK: - Migration Manager Implementation

class DataMigrationManager: DataMigrationManagerProtocol {
    private let dataManager: DataManager
    private let userDefaults: UserDefaults
    private let fileManager = FileManager.default
    
    private let currentSchemaVersion = "1.0"
    private let schemaVersionKey = "AudioTourSchemaVersion"
    
    init(dataManager: DataManager = DataManager.shared, userDefaults: UserDefaults = .standard) {
        self.dataManager = dataManager
        self.userDefaults = userDefaults
    }
    
    // MARK: - Migration Management
    
    func performMigration() async throws {
        guard try await needsMigration() else {
            return
        }
        
        let migrationPlan = try await getMigrationPlan()
        
        // Create backup before migration
        let backupURL = try await performBackup()
        
        do {
            // Execute migration steps
            for step in migrationPlan.steps {
                try await executeMigrationStep(step)
            }
            
            // Update schema version
            userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
            
            // Clean up old backup after successful migration
            try? fileManager.removeItem(at: backupURL)
            
        } catch {
            // Restore from backup if migration fails
            try await restoreFromBackup(backupURL)
            throw DataError.migrationFailed(error)
        }
    }
    
    func getCurrentSchemaVersion() async throws -> String {
        return userDefaults.string(forKey: schemaVersionKey) ?? "1.0"
    }
    
    func needsMigration() async throws -> Bool {
        let storedVersion = try await getCurrentSchemaVersion()
        return storedVersion != currentSchemaVersion
    }
    
    func getMigrationPlan() async throws -> MigrationPlan {
        let fromVersion = try await getCurrentSchemaVersion()
        let toVersion = currentSchemaVersion
        
        var steps: [MigrationStep] = []
        
        // Define migration paths
        if fromVersion == "1.0" && toVersion == "1.1" {
            steps.append(MigrationStep(
                fromVersion: "1.0",
                toVersion: "1.1",
                description: "Add audio quality preferences",
                operation: .addField(entity: "UserPreferences", field: "audioQuality", defaultValue: "high")
            ))
        }
        
        // Add more migration paths as needed
        
        return MigrationPlan(
            fromVersion: fromVersion,
            toVersion: toVersion,
            steps: steps,
            estimatedDuration: TimeInterval(steps.count * 5) // 5 seconds per step estimate
        )
    }
    
    // MARK: - Backup and Restore
    
    func performBackup() async throws -> URL {
        let backupDirectory = getBackupDirectory()
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = backupDirectory.appendingPathComponent("backup_\(timestamp).json")
        
        // Create comprehensive backup
        let backupData = try await createBackupData()
        try backupData.write(to: backupURL)
        
        return backupURL
    }
    
    func restoreFromBackup(_ backupURL: URL) async throws {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw DataError.fileNotAccessible(backupURL.path)
        }
        
        let backupData = try Data(contentsOf: backupURL)
        try await restoreFromBackupData(backupData)
    }
    
    // MARK: - Private Migration Methods
    
    private func executeMigrationStep(_ step: MigrationStep) async throws {
        switch step.operation {
        case .addField(let entity, let field, let defaultValue):
            try await addFieldMigration(entity: entity, field: field, defaultValue: defaultValue)
            
        case .removeField(let entity, let field):
            try await removeFieldMigration(entity: entity, field: field)
            
        case .renameField(let entity, let oldField, let newField):
            try await renameFieldMigration(entity: entity, oldField: oldField, newField: newField)
            
        case .addEntity(let entityName):
            try await addEntityMigration(entityName: entityName)
            
        case .removeEntity(let entityName):
            try await removeEntityMigration(entityName: entityName)
            
        case .customMigration(let migrationBlock):
            try await migrationBlock(dataManager)
        }
    }
    
    private func addFieldMigration(entity: String, field: String, defaultValue: Any) async throws {
        // SwiftData handles schema evolution automatically in most cases
        // For custom logic, implement specific migration code here
        
        switch entity {
        case "UserPreferences":
            if field == "audioQuality" {
                let preferences = try await dataManager.fetchFirst(UserPreferences.self, predicate: nil)
                if let prefs = preferences {
                    // Set default audio quality if not already set
                    if prefs.audioQuality == .low { // Assuming this means it wasn't set
                        prefs.audioQuality = .high
                        try await dataManager.save(prefs)
                    }
                }
            }
            
        default:
            break
        }
    }
    
    private func removeFieldMigration(entity: String, field: String) async throws {
        // Handle field removal if needed
        // SwiftData typically handles this automatically
    }
    
    private func renameFieldMigration(entity: String, oldField: String, newField: String) async throws {
        // Handle field renaming
        // This would require custom migration logic
    }
    
    private func addEntityMigration(entityName: String) async throws {
        // Handle new entity addition
        // SwiftData handles this automatically with schema updates
    }
    
    private func removeEntityMigration(entityName: String) async throws {
        // Handle entity removal
        // Clean up data if needed
    }
    
    // MARK: - Backup Data Management
    
    private func createBackupData() async throws -> Data {
        var backupDict: [String: Any] = [:]
        
        // Create simplified backup data for SwiftData models (they don't conform to Codable)
        
        // Backup tours as basic data
        let tours = try await dataManager.fetch(Tour.self)
        let toursData = tours.map { tour in
            return [
                "id": tour.id.uuidString,
                "name": tour.name,
                "description": tour.tourDescription,
                "language": tour.language,
                "category": tour.category.rawValue,
                "difficulty": tour.difficulty.rawValue,
                "estimatedDuration": tour.estimatedDuration,
                "totalDistance": tour.totalDistance
            ]
        }
        backupDict["tours"] = toursData
        
        // Backup POIs as basic data
        let pois = try await dataManager.fetch(PointOfInterest.self)
        let poisData = pois.map { poi in
            return [
                "id": poi.id.uuidString,
                "tourId": poi.tourId.uuidString,
                "name": poi.name,
                "description": poi.poiDescription,
                "latitude": poi.latitude,
                "longitude": poi.longitude,
                "radius": poi.radius,
                "order": poi.order
            ]
        }
        backupDict["pois"] = poisData
        
        // Backup user preferences (this one has Codable)
        let preferences = try await dataManager.fetch(UserPreferences.self)
        if let firstPreference = preferences.first {
            let preferencesData = try JSONEncoder().encode(firstPreference)
            backupDict["preferences"] = try JSONSerialization.jsonObject(with: preferencesData)
        }
        
        // Add metadata
        backupDict["version"] = currentSchemaVersion
        backupDict["timestamp"] = Date().timeIntervalSince1970
        backupDict["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        return try JSONSerialization.data(withJSONObject: backupDict, options: .prettyPrinted)
    }
    
    private func restoreFromBackupData(_ data: Data) async throws {
        guard try JSONSerialization.jsonObject(with: data) as? [String: Any] != nil else {
            throw DataError.invalidData("Invalid backup format")
        }
        
        // Clear existing data
        try await dataManager.deleteAll(Tour.self)
        try await dataManager.deleteAll(PointOfInterest.self)
        try await dataManager.deleteAll(AudioContent.self)
        try await dataManager.deleteAll(UserPreferences.self)
        
        // Note: This is a simplified restore - full implementation would require 
        // recreating models from the basic data structures
        // For now, just log that backup/restore functionality needs enhancement
        print("Backup restore functionality requires enhancement for SwiftData models")
    }
    
    private func getBackupDirectory() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Backups")
    }
    
    // MARK: - Migration Utilities
    
    func cleanupOldBackups() async throws {
        let backupDirectory = getBackupDirectory()
        
        guard fileManager.fileExists(atPath: backupDirectory.path) else { return }
        
        let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        // Keep only the 5 most recent backups
        let sortedBackups = backupFiles.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
        
        for backup in sortedBackups.dropFirst(5) {
            try? fileManager.removeItem(at: backup)
        }
    }
    
    func validateDataIntegrity() async throws -> DataIntegrityReport {
        var issues: [DataIntegrityIssue] = []
        
        // Check for orphaned POIs (POIs without tours)
        let pois = try await dataManager.fetch(PointOfInterest.self)
        let tours = try await dataManager.fetch(Tour.self)
        let tourIds = Set(tours.map { $0.id })
        
        for poi in pois {
            if !tourIds.contains(poi.tourId) {
                issues.append(DataIntegrityIssue(
                    type: .orphanedRecord,
                    entity: "PointOfInterest",
                    recordId: poi.id,
                    description: "POI \(poi.name) references non-existent tour \(poi.tourId)"
                ))
            }
        }
        
        // Check for orphaned audio content
        let audioContent = try await dataManager.fetch(AudioContent.self)
        let poiIds = Set(pois.map { $0.id })
        
        for content in audioContent {
            if !poiIds.contains(content.poiId) {
                issues.append(DataIntegrityIssue(
                    type: .orphanedRecord,
                    entity: "AudioContent",
                    recordId: content.id,
                    description: "Audio content references non-existent POI \(content.poiId)"
                ))
            }
        }
        
        // Check for missing audio files
        for content in audioContent {
            if let localURLString = content.localFileURL {
                if !fileManager.fileExists(atPath: localURLString) {
                    issues.append(DataIntegrityIssue(
                        type: .missingFile,
                        entity: "AudioContent",
                        recordId: content.id,
                        description: "Missing audio file at \(localURLString)"
                    ))
                }
            }
        }
        
        return DataIntegrityReport(
            totalRecords: tours.count + pois.count + audioContent.count,
            issuesFound: issues.count,
            issues: issues,
            lastChecked: Date()
        )
    }
    
    func repairDataIntegrity(_ report: DataIntegrityReport) async throws {
        for issue in report.issues {
            switch issue.type {
            case .orphanedRecord:
                try await handleOrphanedRecord(issue)
            case .missingFile:
                try await handleMissingFile(issue)
            case .corruptedData:
                try await handleCorruptedData(issue)
            }
        }
    }
    
    private func handleOrphanedRecord(_ issue: DataIntegrityIssue) async throws {
        // Remove orphaned records
        switch issue.entity {
        case "PointOfInterest":
            if let poi = try await dataManager.fetch(PointOfInterest.self).first(where: { $0.id == issue.recordId }) {
                try await dataManager.delete(poi)
            }
        case "AudioContent":
            if let content = try await dataManager.fetch(AudioContent.self).first(where: { $0.id == issue.recordId }) {
                try await dataManager.delete(content)
            }
        default:
            break
        }
    }
    
    private func handleMissingFile(_ issue: DataIntegrityIssue) async throws {
        // Reset download status for missing files
        if let content = try await dataManager.fetch(AudioContent.self).first(where: { $0.id == issue.recordId }) {
            content.localFileURL = nil
            content.downloadStatus = .notStarted
            content.cachedAt = nil
            try await dataManager.save(content)
        }
    }
    
    private func handleCorruptedData(_ issue: DataIntegrityIssue) async throws {
        // Handle corrupted data on a case-by-case basis
        // Could involve resetting to default values or removing the record
    }
}

// MARK: - Supporting Types

struct MigrationPlan {
    let fromVersion: String
    let toVersion: String
    let steps: [MigrationStep]
    let estimatedDuration: TimeInterval
}

struct MigrationStep {
    let fromVersion: String
    let toVersion: String
    let description: String
    let operation: MigrationOperation
}

enum MigrationOperation {
    case addField(entity: String, field: String, defaultValue: Any)
    case removeField(entity: String, field: String)
    case renameField(entity: String, oldField: String, newField: String)
    case addEntity(entityName: String)
    case removeEntity(entityName: String)
    case customMigration((DataManager) async throws -> Void)
}

struct DataIntegrityReport {
    let totalRecords: Int
    let issuesFound: Int
    let issues: [DataIntegrityIssue]
    let lastChecked: Date
    
    var isHealthy: Bool {
        return issuesFound == 0
    }
}

struct DataIntegrityIssue {
    let type: IntegrityIssueType
    let entity: String
    let recordId: UUID
    let description: String
}

enum IntegrityIssueType {
    case orphanedRecord
    case missingFile
    case corruptedData
}