//
//  CarPlayInterfaceController.swift
//  Apple Maps Demo
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CarPlay
import UIKit
import Combine

@MainActor
class CarPlayInterfaceController: ObservableObject {
    
    // MARK: - Properties
    private let interfaceController: CPInterfaceController
    private var audioManager = AudioManager.shared
    private var locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // CarPlay Templates
    private var mapTemplate: CarPlayMapTemplate?
    private var nowPlayingTemplate: CarPlayNowPlayingTemplate?
    private var listTemplate: CarPlayListTemplate?
    
    // Current state
    @Published var isMapDisplayed = true
    @Published var currentTemplate: CPTemplate?
    
    // MARK: - Initialization
    
    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        setupBindings()
        print("🎛️ CarPlayInterfaceController initialized")
    }
    
    deinit {
        cancellables.removeAll()
        print("🧹 CarPlayInterfaceController cleaned up")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Listen for audio state changes to update Now Playing
        audioManager.$isPlaying
            .sink { [weak self] _ in
                self?.updateNowPlayingTemplate()
            }
            .store(in: &cancellables)
        
        audioManager.$currentPOI
            .sink { [weak self] _ in
                self?.updateMapTemplate()
                self?.updateNowPlayingTemplate()
            }
            .store(in: &cancellables)
    }
    
    func setupInitialInterface() {
        // Create and setup the main map template
        createMapTemplate()
        
        // Set the map template as the root template
        if let mapTemplate = mapTemplate?.template {
            interfaceController.setRootTemplate(mapTemplate, animated: false, completion: nil)
            currentTemplate = mapTemplate
            print("🗺️ CarPlay map template set as root")
        }
    }
    
    // MARK: - Template Management
    
    private func createMapTemplate() {
        mapTemplate = CarPlayMapTemplate(
            interfaceController: interfaceController,
            audioManager: audioManager,
            locationManager: locationManager
        )
        
        mapTemplate?.delegate = self
    }
    
    private func createNowPlayingTemplate() {
        nowPlayingTemplate = CarPlayNowPlayingTemplate(
            audioManager: audioManager
        )
        
        nowPlayingTemplate?.delegate = self
    }
    
    private func createListTemplate() {
        listTemplate = CarPlayListTemplate()
        listTemplate?.delegate = self
    }
    
    // MARK: - Template Updates
    
    private func updateMapTemplate() {
        mapTemplate?.updateForCurrentTour()
    }
    
    private func updateNowPlayingTemplate() {
        nowPlayingTemplate?.updateNowPlayingInfo()
    }
    
    // MARK: - Navigation
    
    func showNowPlaying() {
        if nowPlayingTemplate == nil {
            createNowPlayingTemplate()
        }
        
        guard let template = nowPlayingTemplate?.template else { return }
        
        interfaceController.presentTemplate(template, animated: true, completion: nil)
        currentTemplate = template
        print("🎵 CarPlay now playing template presented")
    }
    
    func showTourList() {
        if listTemplate == nil {
            createListTemplate()
        }
        
        guard let template = listTemplate?.template else { return }
        
        interfaceController.presentTemplate(template, animated: true, completion: nil)
        currentTemplate = template
        print("📋 CarPlay tour list template presented")
    }
    
    func showMap() {
        guard let template = mapTemplate?.template else { return }
        
        if currentTemplate != template {
            interfaceController.setRootTemplate(template, animated: true, completion: nil)
            currentTemplate = template
            isMapDisplayed = true
            print("🗺️ CarPlay map template displayed")
        }
    }
    
    func dismissCurrentTemplate() {
        interfaceController.dismissTemplate(animated: true, completion: nil)
        
        // Return to map as default
        if let mapTemplate = mapTemplate?.template {
            currentTemplate = mapTemplate
            isMapDisplayed = true
        }
    }
}

// MARK: - CarPlay Template Delegate

extension CarPlayInterfaceController: CarPlayTemplateDelegate {
    
    func carPlayTemplateDidSelectTour(_ tour: Tour) {
        // Start the selected tour
        Task {
            await audioManager.startTour(tour)
        }
        
        // Return to map to show the active tour
        showMap()
    }
    
    func carPlayTemplateDidRequestNowPlaying() {
        showNowPlaying()
    }
    
    func carPlayTemplateDidRequestTourList() {
        showTourList()
    }
    
    func carPlayTemplateDidRequestPlayPause() {
        Task {
            if audioManager.isPlaying {
                audioManager.pause()
            } else {
                audioManager.resume()
            }
        }
    }
    
    func carPlayTemplateDidRequestSkipForward() {
        Task {
            await audioManager.skipForward()
        }
    }
    
    func carPlayTemplateDidRequestSkipBackward() {
        Task {
            await audioManager.skipBackward()
        }
    }
}

// MARK: - CarPlay Template Delegate Protocol

@MainActor
protocol CarPlayTemplateDelegate: AnyObject {
    func carPlayTemplateDidSelectTour(_ tour: Tour)
    func carPlayTemplateDidRequestNowPlaying()
    func carPlayTemplateDidRequestTourList()
    func carPlayTemplateDidRequestPlayPause()
    func carPlayTemplateDidRequestSkipForward()
    func carPlayTemplateDidRequestSkipBackward()
}