import Foundation
import SwiftData

@Model
final class AudioContent {
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
    
    var isAvailableOffline: Bool {
        return localFileURL != nil
    }
    
    init(
        id: UUID = UUID(),
        poiId: UUID,
        duration: TimeInterval = 0,
        language: String = "en",
        isLLMGenerated: Bool = false
    ) {
        self.id = id
        self.poiId = poiId
        self.duration = duration
        self.language = language
        self.isLLMGenerated = isLLMGenerated
        self.fileSize = 0
    }
    
    func localURL() -> URL? {
        guard let localFileURL = localFileURL else { return nil }
        return URL(fileURLWithPath: localFileURL)
    }
    
    func setLocalURL(_ url: URL) {
        self.localFileURL = url.path
        self.cachedAt = Date()
    }
}

enum AudioContentStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
}

extension AudioContent {
    var estimatedDownloadSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    func clearCache() {
        if let url = localURL() {
            try? FileManager.default.removeItem(at: url)
        }
        localFileURL = nil
        cachedAt = nil
    }
}