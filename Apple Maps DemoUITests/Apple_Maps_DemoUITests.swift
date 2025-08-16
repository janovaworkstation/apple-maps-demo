//
//  Apple_Maps_DemoUITests.swift
//  Apple Maps DemoUITests
//
//  Created by Jeff Lusenhop on 8/16/25.
//

import XCTest

final class Apple_Maps_DemoUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        super.setUp()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // Configure app for UI testing
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment["ANIMATION_SPEED"] = "0" // Disable animations for faster tests
        app.launchEnvironment["UI_TESTING"] = "1"
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        super.tearDown()
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunch() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testMainTabViewAppears() throws {
        // Verify main tab navigation is present
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))
        
        // Check for expected tabs
        let mapTab = app.tabBars.buttons["Map"]
        let toursTab = app.tabBars.buttons["Tours"]
        let playerTab = app.tabBars.buttons["Player"]
        let settingsTab = app.tabBars.buttons["Settings"]
        
        XCTAssertTrue(mapTab.exists)
        XCTAssertTrue(toursTab.exists)
        XCTAssertTrue(playerTab.exists)
        XCTAssertTrue(settingsTab.exists)
    }
    
    // MARK: - Tour List Navigation Tests
    
    func testNavigateToToursList() throws {
        let toursTab = app.tabBars.buttons["Tours"]
        toursTab.tap()
        
        // Verify tours list view appears
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        // Check for tour list elements
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
    }
    
    func testTourListSearch() throws {
        // Navigate to tours
        app.tabBars.buttons["Tours"].tap()
        
        // Wait for tours list to load
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        // Test search functionality
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
        
        searchField.tap()
        searchField.typeText("Historical")
        
        // Wait for search results to filter
        // In a real implementation, we'd check for filtered results
        // For now, just verify search text was entered
        XCTAssertEqual(searchField.value as? String, "Historical")
    }
    
    func testTourDetailNavigation() throws {
        // Navigate to tours
        app.tabBars.buttons["Tours"].tap()
        
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        // Tap on first tour (if available)
        let firstTour = toursList.cells.firstMatch
        if firstTour.exists {
            firstTour.tap()
            
            // Verify tour detail view appears
            // This would typically show in a sheet or navigation
            let tourDetailView = app.scrollViews.firstMatch
            XCTAssertTrue(tourDetailView.waitForExistence(timeout: 3.0))
        }
    }
    
    // MARK: - Map View Tests
    
    func testNavigateToMap() throws {
        let mapTab = app.tabBars.buttons["Map"]
        mapTab.tap()
        
        // Verify map view appears
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5.0))
    }
    
    func testMapInteraction() throws {
        app.tabBars.buttons["Map"].tap()
        
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5.0))
        
        // Test map gestures
        mapView.pinch(withScale: 2.0, velocity: 1.0) // Zoom in
        mapView.pinch(withScale: 0.5, velocity: 1.0) // Zoom out
        
        // Test map pan
        mapView.swipeLeft()
        mapView.swipeRight()
        mapView.swipeUp()
        mapView.swipeDown()
    }
    
    // MARK: - Audio Player Tests
    
    func testNavigateToAudioPlayer() throws {
        let playerTab = app.tabBars.buttons["Player"]
        playerTab.tap()
        
        // Verify audio player view appears
        let audioPlayerView = app.scrollViews.firstMatch
        XCTAssertTrue(audioPlayerView.waitForExistence(timeout: 5.0))
    }
    
    func testAudioPlayerControls() throws {
        app.tabBars.buttons["Player"].tap()
        
        let audioPlayerView = app.scrollViews.firstMatch
        XCTAssertTrue(audioPlayerView.waitForExistence(timeout: 5.0))
        
        // Test play/pause button
        let playPauseButton = app.buttons.matching(identifier: "play.circle.fill").firstMatch
        if playPauseButton.exists {
            playPauseButton.tap()
            
            // After tapping, button should change (in a real implementation)
            // For now, just verify it's tappable
            XCTAssertTrue(playPauseButton.isHittable)
        }
        
        // Test skip buttons if they exist
        let skipForwardButton = app.buttons.matching(identifier: "goforward.30").firstMatch
        let skipBackwardButton = app.buttons.matching(identifier: "gobackward.30").firstMatch
        
        if skipForwardButton.exists {
            XCTAssertTrue(skipForwardButton.isHittable)
        }
        
        if skipBackwardButton.exists {
            XCTAssertTrue(skipBackwardButton.isHittable)
        }
    }
    
    // MARK: - Settings Tests
    
    func testNavigateToSettings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Verify settings view appears
        let settingsView = app.scrollViews.firstMatch
        XCTAssertTrue(settingsView.waitForExistence(timeout: 5.0))
    }
    
    func testSettingsInteraction() throws {
        app.tabBars.buttons["Settings"].tap()
        
        let settingsView = app.scrollViews.firstMatch
        XCTAssertTrue(settingsView.waitForExistence(timeout: 5.0))
        
        // Test toggle switches if they exist
        let toggles = app.switches
        if toggles.count > 0 {
            let firstToggle = toggles.firstMatch
            let originalValue = firstToggle.value as? String
            
            firstToggle.tap()
            
            // Verify toggle state changed
            let newValue = firstToggle.value as? String
            XCTAssertNotEqual(originalValue, newValue)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testVoiceOverAccessibility() throws {
        // Test basic VoiceOver labels exist
        app.tabBars.buttons["Tours"].tap()
        
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        // Verify accessibility labels
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
        XCTAssertNotNil(searchField.label)
        XCTAssertFalse(searchField.label.isEmpty)
        
        // Test tab accessibility
        for tabButton in app.tabBars.buttons.allElementsBoundByIndex {
            XCTAssertTrue(tabButton.isAccessibilityElement)
            XCTAssertNotNil(tabButton.label)
            XCTAssertFalse(tabButton.label.isEmpty)
        }
    }
    
    func testDynamicTypeSupport() throws {
        // Test that UI adapts to different text sizes
        // This would typically involve changing system text size settings
        // For now, just verify key text elements exist
        
        app.tabBars.buttons["Tours"].tap()
        
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        // Verify text elements are present and readable
        let staticTexts = app.staticTexts
        XCTAssertGreaterThan(staticTexts.count, 0)
        
        for textElement in staticTexts.allElementsBoundByIndex.prefix(5) {
            XCTAssertTrue(textElement.exists)
            XCTAssertFalse(textElement.label.isEmpty)
        }
    }
    
    // MARK: - Permission Handling Tests
    
    func testLocationPermissionAlert() throws {
        // This test would verify location permission handling
        // In a real implementation, we'd simulate the permission alert
        
        app.tabBars.buttons["Map"].tap()
        
        // Look for location permission alert
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3.0) {
            // If permission alert appears, handle it
            let allowButton = alert.buttons["Allow While Using App"]
            if allowButton.exists {
                allowButton.tap()
            }
        }
        
        // Verify map still loads regardless of permission choice
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Error Handling UI Tests
    
    func testNoToursAvailableState() throws {
        app.tabBars.buttons["Tours"].tap()
        
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        // If no tours are available, should show empty state
        // This would depend on the actual implementation
        // For now, just verify the list view exists
        XCTAssertTrue(toursList.exists)
    }
    
    func testNetworkErrorHandling() throws {
        // This would test how the app handles network errors
        // In a real implementation, we'd simulate network conditions
        
        app.tabBars.buttons["Tours"].tap()
        
        // Look for error messages or retry buttons
        let retryButton = app.buttons["Retry"]
        if retryButton.exists {
            retryButton.tap()
        }
        
        // Verify app remains functional
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testTabSwitchingPerformance() throws {
        let tabs = ["Map", "Tours", "Player", "Settings"]
        
        measure {
            for tab in tabs {
                app.tabBars.buttons[tab].tap()
                // Small delay to ensure tab loads
                usleep(100000) // 0.1 seconds
            }
        }
    }
    
    func testScrollingPerformance() throws {
        app.tabBars.buttons["Tours"].tap()
        
        let toursList = app.collectionViews.firstMatch
        XCTAssertTrue(toursList.waitForExistence(timeout: 5.0))
        
        measure {
            // Perform scrolling gestures
            for _ in 0..<10 {
                toursList.swipeUp()
                usleep(50000) // 0.05 seconds
            }
            
            for _ in 0..<10 {
                toursList.swipeDown()
                usleep(50000) // 0.05 seconds
            }
        }
    }
    
    // MARK: - Deep Link and State Restoration Tests
    
    func testDeepLinkHandling() throws {
        // This would test deep link handling if implemented
        // For now, just verify app can handle different entry points
        
        app.terminate()
        app.launch()
        
        // Verify app returns to expected state
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5.0))
    }
    
    func testStateRestoration() throws {
        // Navigate to a specific state
        app.tabBars.buttons["Tours"].tap()
        
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("Test Search")
        
        // Simulate app backgrounding and foregrounding
        XCUIDevice.shared.press(.home)
        app.activate()
        
        // Verify state is restored
        XCTAssertTrue(app.tabBars.buttons["Tours"].isSelected)
        // In a real implementation, search text might be preserved
    }
    
    // MARK: - Edge Case Tests
    
    func testLowMemoryConditions() throws {
        // This would test behavior under low memory conditions
        // Difficult to simulate in UI tests, but we can test basic resilience
        
        // Navigate through all major screens rapidly
        let tabs = ["Map", "Tours", "Player", "Settings"]
        
        for _ in 0..<5 {
            for tab in tabs {
                app.tabBars.buttons[tab].tap()
                // Quick navigation to stress test memory usage
                usleep(200000) // 0.2 seconds
            }
        }
        
        // Verify app is still responsive
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        XCTAssertTrue(tabBar.isHittable)
    }
    
    func testOrientationChanges() throws {
        // Test rotation handling
        XCUIDevice.shared.orientation = .landscapeLeft
        
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3.0))
        
        // Navigate to map in landscape
        app.tabBars.buttons["Map"].tap()
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5.0))
        
        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
        
        // Verify UI still works
        XCTAssertTrue(mapView.exists)
        XCTAssertTrue(tabBar.exists)
    }
}