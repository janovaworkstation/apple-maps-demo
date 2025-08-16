//
//  CarPlaySceneDelegate.swift
//  Apple Maps Demo
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    // MARK: - Properties
    var interfaceController: CPInterfaceController?
    var carPlayInterfaceController: CarPlayInterfaceController?
    
    // MARK: - Scene Lifecycle
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, 
                                 didConnect interfaceController: CPInterfaceController) {
        print("🚗 CarPlay scene connected")
        
        self.interfaceController = interfaceController
        
        // Create our custom CarPlay interface controller
        self.carPlayInterfaceController = CarPlayInterfaceController(interfaceController: interfaceController)
        
        // Setup initial templates
        setupInitialInterface()
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, 
                                 didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        print("🚗 CarPlay scene disconnected")
        
        self.interfaceController = nil
        self.carPlayInterfaceController = nil
        
        // Clean up CarPlay-specific resources
        cleanupCarPlayResources()
    }
    
    // MARK: - Interface Setup
    
    private func setupInitialInterface() {
        guard let carPlayController = carPlayInterfaceController else { return }
        
        // Start with the main map template as the root
        carPlayController.setupInitialInterface()
    }
    
    private func cleanupCarPlayResources() {
        // Perform any necessary cleanup when CarPlay disconnects
        // This ensures the phone app continues working normally
        print("🧹 Cleaning up CarPlay resources")
    }
}

// MARK: - CarPlay Template Delegate Methods

extension CarPlaySceneDelegate {
    
    // Handle deep linking or specific CarPlay entry points
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                 didSelectNavigationAlert navigationAlert: CPNavigationAlert) {
        // Handle navigation alerts if needed
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                 didSelectManeuver maneuver: CPManeuver) {
        // Handle turn-by-turn navigation if implemented
    }
}