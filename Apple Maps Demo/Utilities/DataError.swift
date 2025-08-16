import Foundation

// MARK: - Data Layer Error Types

enum DataError: LocalizedError {
    // Core Data/SwiftData Errors
    case contextNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case entityNotFound(String)
    case invalidModelContext
    
    // Validation Errors
    case validationFailed(String)
    case invalidData(String)
    case missingRequiredField(String)
    case duplicateEntry(String)
    
    // Migration Errors
    case migrationFailed(Error)
    case incompatibleSchema(String)
    case migrationNotSupported(String)
    
    // Repository Errors
    case repositoryError(String)
    case queryFailed(String)
    case batchOperationFailed(Error)
    
    // File System Errors
    case fileSystemError(Error)
    case diskSpaceFull
    case fileNotAccessible(String)
    
    // Network/Sync Errors
    case syncFailed(Error)
    case networkUnavailable
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        // Core Data/SwiftData Errors
        case .contextNotFound:
            return "Database context not found"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .entityNotFound(let entityName):
            return "Entity '\(entityName)' not found"
        case .invalidModelContext:
            return "Invalid model context"
            
        // Validation Errors
        case .validationFailed(let details):
            return "Validation failed: \(details)"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .missingRequiredField(let fieldName):
            return "Required field '\(fieldName)' is missing"
        case .duplicateEntry(let details):
            return "Duplicate entry: \(details)"
            
        // Migration Errors
        case .migrationFailed(let error):
            return "Data migration failed: \(error.localizedDescription)"
        case .incompatibleSchema(let details):
            return "Incompatible schema: \(details)"
        case .migrationNotSupported(let details):
            return "Migration not supported: \(details)"
            
        // Repository Errors
        case .repositoryError(let details):
            return "Repository error: \(details)"
        case .queryFailed(let details):
            return "Query failed: \(details)"
        case .batchOperationFailed(let error):
            return "Batch operation failed: \(error.localizedDescription)"
            
        // File System Errors
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .diskSpaceFull:
            return "Insufficient disk space"
        case .fileNotAccessible(let path):
            return "File not accessible: \(path)"
            
        // Network/Sync Errors
        case .syncFailed(let error):
            return "Synchronization failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflicts"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .contextNotFound, .invalidModelContext:
            return "Restart the application"
        case .saveFailed, .fetchFailed, .deleteFailed:
            return "Try again or restart the application"
        case .validationFailed, .invalidData, .missingRequiredField:
            return "Check your input and try again"
        case .duplicateEntry:
            return "Use a different name or identifier"
        case .migrationFailed:
            return "Contact support if this persists"
        case .diskSpaceFull:
            return "Free up storage space and try again"
        case .networkUnavailable:
            return "Check your internet connection"
        case .syncFailed:
            return "Try syncing again when network is stable"
        default:
            return "Try again later or contact support"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .contextNotFound: return 1001
        case .saveFailed: return 1002
        case .fetchFailed: return 1003
        case .deleteFailed: return 1004
        case .entityNotFound: return 1005
        case .invalidModelContext: return 1006
        case .validationFailed: return 2001
        case .invalidData: return 2002
        case .missingRequiredField: return 2003
        case .duplicateEntry: return 2004
        case .migrationFailed: return 3001
        case .incompatibleSchema: return 3002
        case .migrationNotSupported: return 3003
        case .repositoryError: return 4001
        case .queryFailed: return 4002
        case .batchOperationFailed: return 4003
        case .fileSystemError: return 5001
        case .diskSpaceFull: return 5002
        case .fileNotAccessible: return 5003
        case .syncFailed: return 6001
        case .networkUnavailable: return 6002
        case .conflictResolutionFailed: return 6003
        }
    }
}

// MARK: - Data Operation Result

enum DataResult<T> {
    case success(T)
    case failure(DataError)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isFailure: Bool {
        return !isSuccess
    }
    
    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }
    
    var error: DataError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

// MARK: - Data Operation Completion Types

typealias DataCompletion<T> = (DataResult<T>) -> Void
typealias VoidCompletion = (DataResult<Void>) -> Void
typealias BoolCompletion = (DataResult<Bool>) -> Void

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    
    static let valid = ValidationResult(isValid: true, errors: [])
    
    static func invalid(_ errors: [String]) -> ValidationResult {
        return ValidationResult(isValid: false, errors: errors)
    }
    
    static func invalid(_ error: String) -> ValidationResult {
        return ValidationResult(isValid: false, errors: [error])
    }
}

// MARK: - Data Query Options

struct QueryOptions {
    let limit: Int?
    let offset: Int?
    let sortDescriptors: [SortDescriptor<AnyObject>]
    let includesPendingChanges: Bool
    
    init(
        limit: Int? = nil,
        offset: Int? = nil,
        sortDescriptors: [SortDescriptor<AnyObject>] = [],
        includesPendingChanges: Bool = true
    ) {
        self.limit = limit
        self.offset = offset
        self.sortDescriptors = sortDescriptors
        self.includesPendingChanges = includesPendingChanges
    }
    
    static let `default` = QueryOptions()
}

// MARK: - Batch Operation Result

struct BatchOperationResult {
    let successCount: Int
    let failureCount: Int
    let errors: [DataError]
    
    var totalOperations: Int {
        return successCount + failureCount
    }
    
    var isCompleteSuccess: Bool {
        return failureCount == 0
    }
    
    var isPartialSuccess: Bool {
        return successCount > 0 && failureCount > 0
    }
    
    var isCompleteFailure: Bool {
        return successCount == 0 && failureCount > 0
    }
}