//
//  CarPlayNowPlayingTemplate.swift
//  Apple Maps Demo
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CarPlay
import MediaPlayer
import Combine

@MainActor
class CarPlayNowPlayingTemplate: NSObject {
    
    // MARK: - Properties
    private let audioManager: AudioManager
    private var cancellables = Set<AnyCancellable>()
    
    // Template
    private(set) var template: CPNowPlayingTemplate
    
    // Delegate
    weak var delegate: CarPlayTemplateDelegate?
    
    // Now Playing Info
    private var currentNowPlayingInfo: [String: Any] = [:]
    
    // MARK: - Initialization
    
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        self.template = CPNowPlayingTemplate.shared
        
        super.init()
        
        setupNowPlayingTemplate()
        setupBindings()
        updateNowPlayingInfo()
        
        print("🎵 CarPlayNowPlayingTemplate initialized")
    }
    
    deinit {
        cancellables.removeAll()
        print("🧹 CarPlayNowPlayingTemplate cleaned up")
    }
    
    // MARK: - Setup
    
    private func setupNowPlayingTemplate() {
        // Setup album art placeholder
        setupAlbumArt()
        
        // Update button states
        updatePlaybackButtons()
    }
    
    private func setupBindings() {
        // Listen for audio state changes
        audioManager.$isPlaying
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
                self?.updatePlaybackButtons()
            }
            .store(in: &cancellables)
        
        audioManager.$currentPOI
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
                self?.setupAlbumArt()
            }
            .store(in: &cancellables)
        
        audioManager.$currentTime
            .sink { [weak self] _ in
                self?.updatePlaybackTime()
            }
            .store(in: &cancellables)
        
        audioManager.$duration
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)
        
        audioManager.$playbackRate
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func updateNowPlayingInfo() {
        setupNowPlayingInfoCenter()
        updatePlaybackButtons()
    }
    
    // MARK: - Private Methods
    
    private func setupNowPlayingInfoCenter() {
        var nowPlayingInfo: [String: Any] = [:]
        
        // Basic track information
        if let poi = audioManager.currentPOI {
            nowPlayingInfo[MPMediaItemPropertyTitle] = poi.name
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Audio Tour"
            
            if let tour = audioManager.currentTourPublic {
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = tour.name
            }
        } else {
            nowPlayingInfo[MPMediaItemPropertyTitle] = "Audio Tour"
            nowPlayingInfo[MPMediaItemPropertyArtist] = "No Active Tour"
        }
        
        // Playback information
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = audioManager.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioManager.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = audioManager.isPlaying ? audioManager.playbackRate : 0.0
        
        // Media type
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPMediaType.audioBook.rawValue
        
        // Store for comparison
        currentNowPlayingInfo = nowPlayingInfo
        
        // Update the system's now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updatePlaybackTime() {
        // Update only the elapsed time to avoid rebuilding the entire info
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioManager.currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = audioManager.isPlaying ? audioManager.playbackRate : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
    
    private func setupAlbumArt() {
        // Create a generic album art image for the tour
        let artworkImage = createAlbumArtwork()
        let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
            return artworkImage
        }
        
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func createAlbumArtwork() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemTeal.cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Add map pin icon
            let pinSize: CGFloat = 100
            let pinRect = CGRect(
                x: (size.width - pinSize) / 2,
                y: (size.height - pinSize) / 2,
                width: pinSize,
                height: pinSize
            )
            
            if let pinImage = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                pinImage.draw(in: pinRect)
            }
            
            // Add tour name if available
            if let tour = audioManager.currentTourPublic {
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: UIColor.white,
                    .strokeColor: UIColor.black,
                    .strokeWidth: -2.0
                ]
                
                let titleSize = tour.name.size(withAttributes: titleAttributes)
                let titleRect = CGRect(
                    x: (size.width - titleSize.width) / 2,
                    y: size.height - titleSize.height - 20,
                    width: titleSize.width,
                    height: titleSize.height
                )
                
                tour.name.draw(in: titleRect, withAttributes: titleAttributes)
            }
        }
    }
    
    private func updatePlaybackButtons() {
        // CarPlay automatically updates button states based on the command center
        // We just need to ensure our remote command center is properly configured
        setupRemoteCommandCenter()
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = !audioManager.isPlaying
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestPlayPause()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = audioManager.isPlaying
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestPlayPause()
            return .success
        }
        
        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestPlayPause()
            return .success
        }
        
        // Skip forward command (30 seconds)
        commandCenter.skipForwardCommand.isEnabled = audioManager.currentPOI != nil
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestSkipForward()
            return .success
        }
        
        // Skip backward command (30 seconds)
        commandCenter.skipBackwardCommand.isEnabled = audioManager.currentPOI != nil
        commandCenter.skipBackwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.delegate?.carPlayTemplateDidRequestSkipBackward()
            return .success
        }
        
        // Seek commands (for scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = audioManager.currentPOI != nil
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            // Seek to the specified position
            Task { @MainActor in
                await self?.audioManager.seekToTime(event.positionTime)
            }
            
            return .success
        }
        
        // Disable commands we don't support
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changeRepeatModeCommand.isEnabled = false
        commandCenter.changeShuffleModeCommand.isEnabled = false
        commandCenter.ratingCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
        commandCenter.dislikeCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
    }
}

// MARK: - CarPlay Now Playing Support

extension CarPlayNowPlayingTemplate {
    
    func handleUpNextButtonTapped() {
        // Show upcoming POIs or queue
        // This could trigger showing a list of upcoming tour stops
        print("🎵 CarPlay up next button tapped")
    }
    
    func handleAlbumArtistButtonTapped() {
        // Show tour information or return to map
        delegate?.carPlayTemplateDidRequestTourList()
    }
}