import Foundation

// MARK: - DownloadTask Class

@MainActor
class DownloadTask: NSObject, ObservableObject {
    let id: UUID
    let remoteURL: URL
    let localURL: URL
    let audioContent: AudioContent
    let priority: DownloadPriority
    
    @Published private(set) var state: DownloadState = .pending
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var bytesDownloaded: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var error: Error?
    
    private var downloadTask: URLSessionDownloadTask?
    private let session: URLSession
    private var progressHandler: ((Double) async -> Void)?
    private var completionHandler: ((Result<URL, Error>) async -> Void)?
    
    // MARK: - Initialization
    
    init(
        id: UUID,
        remoteURL: URL,
        localURL: URL,
        audioContent: AudioContent,
        priority: DownloadPriority,
        session: URLSession
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.localURL = localURL
        self.audioContent = audioContent
        self.priority = priority
        self.session = session
        super.init()
    }
    
    // MARK: - Download Control
    
    func start(
        progress: @escaping (Double) async -> Void,
        completion: @escaping (Result<URL, Error>) async -> Void
    ) async throws {
        guard state == .pending || state == .paused else {
            throw DownloadTaskError.invalidState
        }
        
        self.progressHandler = progress
        self.completionHandler = completion
        
        // Create download request
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 60.0
        
        // Add headers for better download handling
        request.setValue("audio/*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        // Create download task
        downloadTask = session.downloadTask(with: request) { [weak self] tempURL, response, error in
            Task { @MainActor [weak self] in
                await self?.handleDownloadCompletion(tempURL: tempURL, response: response, error: error)
            }
        }
        
        // Set download priority
        downloadTask?.priority = priority.urlSessionPriority
        
        // Start download
        downloadTask?.resume()
        state = .downloading
        
        print("📥 Started download task for: \(audioContent.poiId) (\(priority.description) priority)")
    }
    
    func pause() {
        guard state == .downloading else { return }
        
        downloadTask?.suspend()
        state = .paused
        
        print("⏸️ Paused download task for: \(audioContent.poiId)")
    }
    
    func resume() {
        guard state == .paused else { return }
        
        downloadTask?.resume()
        state = .downloading
        
        print("▶️ Resumed download task for: \(audioContent.poiId)")
    }
    
    func cancel() {
        downloadTask?.cancel()
        state = .cancelled
        
        print("🚫 Cancelled download task for: \(audioContent.poiId)")
    }
    
    // MARK: - Private Methods
    
    private func handleDownloadCompletion(
        tempURL: URL?,
        response: URLResponse?,
        error: Error?
    ) async {
        if let error = error {
            self.error = error
            state = .failed
            await completionHandler?(.failure(error))
            return
        }
        
        guard let tempURL = tempURL else {
            let error = DownloadTaskError.noTempURL
            self.error = error
            state = .failed
            await completionHandler?(.failure(error))
            return
        }
        
        // Validate response
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                let error = DownloadTaskError.httpError(httpResponse.statusCode)
                self.error = error
                state = .failed
                await completionHandler?(.failure(error))
                return
            }
            
            // Update total bytes from response headers
            if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
               let bytes = Int64(contentLength) {
                totalBytes = bytes
                audioContent.fileSize = bytes
            }
        }
        
        do {
            // Create destination directory if needed
            let destinationDirectory = localURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            
            // Move downloaded file to final location
            try FileManager.default.moveItem(at: tempURL, to: localURL)
            
            // Verify file was moved successfully
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                throw DownloadTaskError.fileMoveError
            }
            
            // Update file size if not already set
            if totalBytes == 0 {
                let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
                totalBytes = attributes[.size] as? Int64 ?? 0
                audioContent.fileSize = totalBytes
            }
            
            // Validate audio file format
            try await validateAudioFile(at: localURL)
            
            state = .completed
            progress = 1.0
            bytesDownloaded = totalBytes
            
            await completionHandler?(.success(localURL))
            
            print("✅ Download completed successfully for: \(audioContent.poiId)")
            
        } catch {
            self.error = error
            state = .failed
            await completionHandler?(.failure(error))
            
            // Clean up partial file
            try? FileManager.default.removeItem(at: localURL)
            
            print("❌ Download failed during file handling for: \(audioContent.poiId) - \(error)")
        }
    }
    
    private func validateAudioFile(at url: URL) async throws {
        // Basic validation - check if file can be opened as audio
        let asset = AVURLAsset(url: url)
        
        // Check if the asset is playable
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw DownloadTaskError.invalidAudioFile
        }
        
        // Check duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds > 0 && durationSeconds.isFinite else {
            throw DownloadTaskError.invalidAudioDuration
        }
        
        // Update audio content duration
        audioContent.duration = durationSeconds
        
        print("🎵 Audio file validated: \(durationSeconds)s duration")
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadTask: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.bytesDownloaded = totalBytesWritten
            
            if totalBytesExpectedToWrite > 0 {
                self.totalBytes = totalBytesExpectedToWrite
                self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            } else {
                // Estimate progress based on expected file size
                let estimatedSize = max(self.audioContent.fileSize, 1024 * 1024) // Minimum 1MB estimate
                self.progress = min(Double(totalBytesWritten) / Double(estimatedSize), 0.95)
            }
            
            await self.progressHandler?(self.progress)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // This is handled in the completion handler
    }
}

// MARK: - Supporting Types

enum DownloadState {
    case pending
    case downloading
    case paused
    case completed
    case failed
    case cancelled
    
    var description: String {
        switch self {
        case .pending: return "Pending"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        return self == .downloading
    }
    
    var canResume: Bool {
        return self == .paused || self == .failed
    }
    
    var canPause: Bool {
        return self == .downloading
    }
}

enum DownloadTaskError: LocalizedError {
    case invalidState
    case noTempURL
    case httpError(Int)
    case fileMoveError
    case invalidAudioFile
    case invalidAudioDuration
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "Download task is in an invalid state"
        case .noTempURL:
            return "No temporary URL provided for download"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .fileMoveError:
            return "Failed to move downloaded file to destination"
        case .invalidAudioFile:
            return "Downloaded file is not a valid audio file"
        case .invalidAudioDuration:
            return "Audio file has invalid duration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Priority Extension

extension DownloadPriority {
    var urlSessionPriority: Float {
        switch self {
        case .low: return URLSessionTask.lowPriority
        case .normal: return URLSessionTask.defaultPriority
        case .high: return URLSessionTask.highPriority
        case .critical: return URLSessionTask.highPriority
        }
    }
}

import AVFoundation