import Foundation
import SwiftData
import CommonCrypto

@Model
final class AudioContent: @unchecked Sendable {
    var id: UUID
    var poiId: UUID
    var localFileURL: String?
    var remoteURL: String?
    var transcript: String?
    var duration: TimeInterval
    var isLLMGenerated: Bool
    var cachedAt: Date?
    var language: String
    var fileSize: Int64
    var contentHash: String?
    var generationPrompt: String?
    var format: AudioFormat
    var quality: AudioQuality
    var bitrate: Int
    var sampleRate: Int
    var createdAt: Date
    var lastPlayed: Date?
    var playCount: Int
    var downloadStatus: DownloadStatus
    var version: String
    var sourceType: AudioSourceType
    var metadata: AudioMetadata
    
    var isAvailableOffline: Bool {
        return localFileURL != nil && downloadStatus == .completed
    }
    
    init(
        id: UUID = UUID(),
        poiId: UUID,
        duration: TimeInterval = 0,
        language: String = "en",
        isLLMGenerated: Bool = false,
        format: AudioFormat = .mp3,
        quality: AudioQuality = .medium
    ) {
        self.id = id
        self.poiId = poiId
        self.duration = duration
        self.language = language
        self.isLLMGenerated = isLLMGenerated
        self.fileSize = 0
        self.format = format
        self.quality = quality
        self.bitrate = quality.bitrate
        self.sampleRate = 44100 // Standard CD quality
        self.createdAt = Date()
        self.playCount = 0
        self.downloadStatus = .notStarted
        self.version = "1.0"
        self.sourceType = isLLMGenerated ? .generated : .recorded
        self.metadata = AudioMetadata(
            title: "",
            narrator: "",
            contentDescription: "",
            keywords: [],
            mood: "",
            tempo: "",
            genre: "Educational"
        )
    }
}

// MARK: - AudioContent Extensions
extension AudioContent {
    // MARK: - Computed Properties
    
    var isValid: Bool {
        return duration > 0 && !language.isEmpty
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var fileExtension: String {
        return format.fileExtension
    }
    
    var mimeType: String {
        return format.mimeType
    }
    
    var isExpired: Bool {
        guard let cachedAt = cachedAt else { return false }
        let expirationInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days
        return Date().timeIntervalSince(cachedAt) > expirationInterval
    }
    
    var cacheAgeDescription: String {
        guard let cachedAt = cachedAt else { return "Not cached" }
        let interval = Date().timeIntervalSince(cachedAt)
        let days = Int(interval / (24 * 60 * 60))
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
    
    var qualityDescription: String {
        return "\(quality.rawValue) (\(bitrate / 1000)kbps)"
    }
    
    // MARK: - File Management
    
    func localURL() -> URL? {
        guard let localFileURL = localFileURL else { return nil }
        return URL(fileURLWithPath: localFileURL)
    }
    
    func setLocalURL(_ url: URL) {
        self.localFileURL = url.path
        self.cachedAt = Date()
        updateFileSize()
    }
    
    func generateLocalFilename() -> String {
        let sanitizedPOIId = poiId.uuidString.replacingOccurrences(of: "-", with: "")
        return "\(sanitizedPOIId)_\(language)_\(quality.rawValue).\(format.fileExtension)"
    }
    
    func getLocalStorageURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsPath.appendingPathComponent("AudioContent")
        return audioDirectory.appendingPathComponent(generateLocalFilename())
    }
    
    func updateFileSize() {
        guard let url = localURL() else {
            fileSize = 0
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            fileSize = 0
        }
    }
    
    func calculateContentHash() -> String? {
        guard let url = localURL() else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            let hash = data.sha256
            contentHash = hash
            return hash
        } catch {
            return nil
        }
    }
    
    func verifyIntegrity() -> Bool {
        guard let storedHash = contentHash else { return false }
        guard let calculatedHash = calculateContentHash() else { return false }
        return storedHash == calculatedHash
    }
    
    // MARK: - Playback Tracking
    
    func recordPlayback() {
        lastPlayed = Date()
        playCount += 1
    }
    
    func resetPlaybackStats() {
        lastPlayed = nil
        playCount = 0
    }
    
    // MARK: - Cache Management
    
    func clearCache() throws {
        guard let url = localURL() else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
            localFileURL = nil
            cachedAt = nil
            downloadStatus = .notStarted
            fileSize = 0
        } catch {
            throw AudioContentError.cacheCleanupFailed(error.localizedDescription)
        }
    }
    
    func refreshCache() {
        cachedAt = Date()
    }
    
    // MARK: - Download Management
    
    func startDownload() {
        downloadStatus = .inProgress(progress: 0.0)
    }
    
    func updateDownloadProgress(_ progress: Double) {
        downloadStatus = .inProgress(progress: progress)
    }
    
    func completeDownload() {
        downloadStatus = .completed
        cachedAt = Date()
        updateFileSize()
    }
    
    func failDownload(with error: String) {
        downloadStatus = .failed(error: error)
    }
    
    // MARK: - Validation
    
    func validateContent() throws {
        if duration <= 0 {
            throw AudioContentError.invalidDuration
        }
        
        if language.isEmpty {
            throw AudioContentError.invalidLanguage
        }
        
        if isLLMGenerated && (generationPrompt?.isEmpty ?? true) {
            throw AudioContentError.missingGenerationPrompt
        }
        
        if let url = localURL(), !FileManager.default.fileExists(atPath: url.path) {
            throw AudioContentError.fileNotFound
        }
    }
    
    // MARK: - Business Logic
    
    func updateMetadata(title: String? = nil, narrator: String? = nil, description: String? = nil) {
        if let title = title { metadata.title = title }
        if let narrator = narrator { metadata.narrator = narrator }
        if let description = description { metadata.contentDescription = description }
    }
    
    func estimateDownloadTime(connectionSpeed: ConnectionSpeed) -> TimeInterval {
        let bitsPerSecond = connectionSpeed.bitsPerSecond
        let fileSizeInBits = fileSize * 8
        return Double(fileSizeInBits) / Double(bitsPerSecond)
    }
}

// MARK: - Supporting Types

enum AudioFormat: String, Codable, CaseIterable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case wav = "wav"
    case aac = "aac"
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .mp3: return "audio/mpeg"
        case .m4a: return "audio/mp4"
        case .wav: return "audio/wav"
        case .aac: return "audio/aac"
        }
    }
    
    var description: String {
        switch self {
        case .mp3: return "MP3 (MPEG Audio)"
        case .m4a: return "M4A (Apple Lossless)"
        case .wav: return "WAV (Uncompressed)"
        case .aac: return "AAC (Advanced Audio Coding)"
        }
    }
}

enum AudioQuality: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"
    
    var bitrate: Int {
        switch self {
        case .low: return 64000
        case .medium: return 128000
        case .high: return 256000
        case .lossless: return 320000
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Low Quality (64 kbps)"
        case .medium: return "Medium Quality (128 kbps)"
        case .high: return "High Quality (256 kbps)"
        case .lossless: return "Lossless Quality (320 kbps)"
        }
    }
}

enum DownloadStatus: Codable, Equatable {
    case notStarted
    case inProgress(progress: Double)
    case completed
    case failed(error: String)
    case paused
    
    var isDownloading: Bool {
        if case .inProgress = self { return true }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
    
    var description: String {
        switch self {
        case .notStarted: return "Not Downloaded"
        case .inProgress(let progress): return "Downloading (\(Int(progress * 100))%)"
        case .completed: return "Downloaded"
        case .failed(let error): return "Failed: \(error)"
        case .paused: return "Paused"
        }
    }
}

enum AudioSourceType: String, Codable, CaseIterable {
    case recorded = "Recorded"
    case generated = "AI Generated"
    case synthesized = "Text-to-Speech"
    case imported = "Imported"
    
    var iconName: String {
        switch self {
        case .recorded: return "mic"
        case .generated: return "brain"
        case .synthesized: return "speaker.wave.2"
        case .imported: return "square.and.arrow.down"
        }
    }
}

struct AudioMetadata: Codable {
    var title: String
    var narrator: String
    var contentDescription: String
    var keywords: [String]
    var mood: String
    var tempo: String
    var genre: String
    
    init(
        title: String = "",
        narrator: String = "",
        contentDescription: String = "",
        keywords: [String] = [],
        mood: String = "",
        tempo: String = "",
        genre: String = "Educational"
    ) {
        self.title = title
        self.narrator = narrator
        self.contentDescription = contentDescription
        self.keywords = keywords
        self.mood = mood
        self.tempo = tempo
        self.genre = genre
    }
    
    mutating func addKeyword(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty && !keywords.contains(trimmed) {
            keywords.append(trimmed)
        }
    }
    
    mutating func removeKeyword(_ keyword: String) {
        keywords.removeAll { $0.lowercased() == keyword.lowercased() }
    }
}

enum ConnectionSpeed: Int, CaseIterable {
    case slow = 100000      // 100 kbps
    case moderate = 1000000 // 1 Mbps
    case fast = 10000000    // 10 Mbps
    case veryFast = 50000000 // 50 Mbps
    
    var bitsPerSecond: Int {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .slow: return "Slow (100 kbps)"
        case .moderate: return "Moderate (1 Mbps)"
        case .fast: return "Fast (10 Mbps)"
        case .veryFast: return "Very Fast (50 Mbps)"
        }
    }
}

enum AudioContentError: LocalizedError {
    case invalidDuration
    case invalidLanguage
    case missingGenerationPrompt
    case fileNotFound
    case cacheCleanupFailed(String)
    case downloadFailed(String)
    case invalidFormat
    case corruptedFile
    
    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Audio duration must be greater than 0"
        case .invalidLanguage:
            return "Language cannot be empty"
        case .missingGenerationPrompt:
            return "Generation prompt is required for LLM-generated content"
        case .fileNotFound:
            return "Audio file not found at specified location"
        case .cacheCleanupFailed(let details):
            return "Failed to clear cache: \(details)"
        case .downloadFailed(let details):
            return "Download failed: \(details)"
        case .invalidFormat:
            return "Unsupported audio format"
        case .corruptedFile:
            return "Audio file appears to be corrupted"
        }
    }
}

// MARK: - Data Extension for Hash Calculation
extension Data {
    var sha256: String {
        let hash = withUnsafeBytes { bytes in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}