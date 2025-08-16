//
//  TourViewModelTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import Combine
@testable import Apple_Maps_Demo

@MainActor
final class TourViewModelTests: XCTestCase {
    
    var tourViewModel: TourViewModel!
    var cancellables: Set<AnyCancellable>!
    var testTours: [Tour]!
    
    override func setUpWithError() throws {
        super.setUp()
        
        tourViewModel = TourViewModel()
        cancellables = Set<AnyCancellable>()
        
        testTours = [
            TestDataFactory.createTour(
                name: "San Francisco Historical Tour",
                description: "Explore the rich history of San Francisco",
                category: .historical,
                tourType: .walking,
                difficulty: .easy
            ),
            TestDataFactory.createTour(
                name: "Golden Gate Park Nature Walk",
                description: "A peaceful walk through Golden Gate Park",
                category: .nature,
                tourType: .walking,
                difficulty: .moderate
            ),
            TestDataFactory.createTour(
                name: "Architecture Drive",
                description: "Architectural marvels of the city",
                category: .architecture,
                tourType: .driving,
                difficulty: .easy
            ),
            TestDataFactory.createTour(
                name: "Cultural Food Tour",
                description: "Taste the diverse cuisines of the city",
                category: .foodAndDrink,
                tourType: .walking,
                difficulty: .moderate
            )
        ]
    }
    
    override func tearDownWithError() throws {
        tourViewModel = nil
        cancellables?.removeAll()
        cancellables = nil
        testTours = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testTourViewModelInitialization() {
        XCTAssertTrue(tourViewModel.tours.isEmpty)
        XCTAssertTrue(tourViewModel.filteredTours.isEmpty)
        XCTAssertFalse(tourViewModel.isLoading)
        XCTAssertNil(tourViewModel.errorMessage)
        XCTAssertEqual(tourViewModel.searchText, "")
        XCTAssertEqual(tourViewModel.selectedCategory, .all)
        XCTAssertEqual(tourViewModel.selectedDifficulty, .all)
        XCTAssertEqual(tourViewModel.selectedTourType, .all)
        XCTAssertEqual(tourViewModel.sortOption, .name)
    }
    
    // MARK: - Tour Loading Tests
    
    func testLoadTours() {
        XCTAssertTrue(tourViewModel.tours.isEmpty)
        XCTAssertFalse(tourViewModel.isLoading)
        
        // Simulate loading tours
        tourViewModel.isLoading = true
        XCTAssertTrue(tourViewModel.isLoading)
        
        // Simulate tours loaded
        tourViewModel.tours = testTours
        tourViewModel.isLoading = false
        
        XCTAssertEqual(tourViewModel.tours.count, testTours.count)
        XCTAssertFalse(tourViewModel.isLoading)
        
        // Verify tours are populated correctly
        for (index, tour) in tourViewModel.tours.enumerated() {
            XCTAssertEqual(tour.id, testTours[index].id)
            XCTAssertEqual(tour.name, testTours[index].name)
        }
    }
    
    func testRefreshTours() {
        // Set initial tours
        tourViewModel.tours = testTours
        XCTAssertEqual(tourViewModel.tours.count, testTours.count)
        
        // Simulate refresh (would typically reload from data source)
        tourViewModel.refreshTours()
        
        // In a real implementation, this would trigger a reload
        // For now, just verify the method can be called
        XCTAssertNotNil(tourViewModel.tours)
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchTours() {
        tourViewModel.tours = testTours
        
        // Test search by name
        tourViewModel.searchText = "Historical"
        tourViewModel.applyFilters()
        
        let historicalTours = tourViewModel.filteredTours.filter { $0.name.contains("Historical") }
        XCTAssertEqual(tourViewModel.filteredTours.count, historicalTours.count)
        XCTAssertTrue(tourViewModel.filteredTours.contains { $0.name.contains("Historical") })
    }
    
    func testSearchToursDescription() {
        tourViewModel.tours = testTours
        
        // Test search by description
        tourViewModel.searchText = "peaceful"
        tourViewModel.applyFilters()
        
        let peacefulTours = tourViewModel.filteredTours.filter { 
            $0.tourDescription.lowercased().contains("peaceful") 
        }
        XCTAssertEqual(tourViewModel.filteredTours.count, peacefulTours.count)
    }
    
    func testSearchToursCaseInsensitive() {
        tourViewModel.tours = testTours
        
        // Test case insensitive search
        tourViewModel.searchText = "HISTORICAL"
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.contains { 
            $0.name.lowercased().contains("historical") 
        })
    }
    
    func testSearchToursEmpty() {
        tourViewModel.tours = testTours
        
        // Test empty search returns all tours
        tourViewModel.searchText = ""
        tourViewModel.applyFilters()
        
        XCTAssertEqual(tourViewModel.filteredTours.count, testTours.count)
    }
    
    func testSearchToursNoResults() {
        tourViewModel.tours = testTours
        
        // Test search with no results
        tourViewModel.searchText = "NonexistentTour"
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.isEmpty)
    }
    
    // MARK: - Category Filter Tests
    
    func testFilterByCategory() {
        tourViewModel.tours = testTours
        
        // Test filter by historical category
        tourViewModel.selectedCategory = .historical
        tourViewModel.applyFilters()
        
        let historicalTours = tourViewModel.filteredTours.filter { $0.category == .historical }
        XCTAssertEqual(tourViewModel.filteredTours.count, historicalTours.count)
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { $0.category == .historical })
    }
    
    func testFilterByAllCategories() {
        tourViewModel.tours = testTours
        
        // Test "all" category shows all tours
        tourViewModel.selectedCategory = .all
        tourViewModel.applyFilters()
        
        XCTAssertEqual(tourViewModel.filteredTours.count, testTours.count)
    }
    
    func testFilterByMultipleCategories() {
        tourViewModel.tours = testTours
        
        // Test different categories
        let categories: [TourCategoryFilter] = [.nature, .architecture, .foodAndDrink]
        
        for category in categories {
            tourViewModel.selectedCategory = category
            tourViewModel.applyFilters()
            
            if category != .all {
                XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { 
                    $0.category.rawValue == category.rawValue 
                })
            }
        }
    }
    
    // MARK: - Difficulty Filter Tests
    
    func testFilterByDifficulty() {
        tourViewModel.tours = testTours
        
        // Test filter by easy difficulty
        tourViewModel.selectedDifficulty = .easy
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { $0.difficulty == .easy })
    }
    
    func testFilterByModerateDifficulty() {
        tourViewModel.tours = testTours
        
        // Test filter by moderate difficulty
        tourViewModel.selectedDifficulty = .moderate
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { $0.difficulty == .moderate })
    }
    
    func testFilterByAllDifficulties() {
        tourViewModel.tours = testTours
        
        // Test "all" difficulty shows all tours
        tourViewModel.selectedDifficulty = .all
        tourViewModel.applyFilters()
        
        XCTAssertEqual(tourViewModel.filteredTours.count, testTours.count)
    }
    
    // MARK: - Tour Type Filter Tests
    
    func testFilterByTourType() {
        tourViewModel.tours = testTours
        
        // Test filter by walking tours
        tourViewModel.selectedTourType = .walking
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { $0.tourType == .walking })
    }
    
    func testFilterByDrivingTours() {
        tourViewModel.tours = testTours
        
        // Test filter by driving tours
        tourViewModel.selectedTourType = .driving
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { $0.tourType == .driving })
    }
    
    func testFilterByAllTourTypes() {
        tourViewModel.tours = testTours
        
        // Test "all" tour type shows all tours
        tourViewModel.selectedTourType = .all
        tourViewModel.applyFilters()
        
        XCTAssertEqual(tourViewModel.filteredTours.count, testTours.count)
    }
    
    // MARK: - Combined Filter Tests
    
    func testCombinedFilters() {
        tourViewModel.tours = testTours
        
        // Test combination of filters
        tourViewModel.selectedCategory = .historical
        tourViewModel.selectedDifficulty = .easy
        tourViewModel.selectedTourType = .walking
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { tour in
            tour.category == .historical && 
            tour.difficulty == .easy && 
            tour.tourType == .walking
        })
    }
    
    func testSearchWithFilters() {
        tourViewModel.tours = testTours
        
        // Test search text combined with category filter
        tourViewModel.searchText = "San Francisco"
        tourViewModel.selectedCategory = .historical
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.allSatisfy { tour in
            tour.name.contains("San Francisco") && tour.category == .historical
        })
    }
    
    // MARK: - Sorting Tests
    
    func testSortByName() {
        tourViewModel.tours = testTours
        tourViewModel.sortOption = .name
        tourViewModel.applyFilters()
        
        let sortedNames = tourViewModel.filteredTours.map { $0.name }
        let expectedSortedNames = testTours.map { $0.name }.sorted()
        
        XCTAssertEqual(sortedNames, expectedSortedNames)
    }
    
    func testSortByDuration() {
        tourViewModel.tours = testTours
        tourViewModel.sortOption = .duration
        tourViewModel.applyFilters()
        
        let sortedDurations = tourViewModel.filteredTours.map { $0.estimatedDuration }
        let expectedSortedDurations = testTours.map { $0.estimatedDuration }.sorted()
        
        XCTAssertEqual(sortedDurations, expectedSortedDurations)
    }
    
    func testSortByPopularity() {
        // Set different ratings for tours
        testTours[0].rating = 4.5
        testTours[1].rating = 3.8
        testTours[2].rating = 4.9
        testTours[3].rating = 4.0
        
        tourViewModel.tours = testTours
        tourViewModel.sortOption = .popularity
        tourViewModel.applyFilters()
        
        let sortedRatings = tourViewModel.filteredTours.map { $0.rating }
        
        // Should be sorted in descending order (highest rating first)
        for i in 1..<sortedRatings.count {
            XCTAssertGreaterThanOrEqual(sortedRatings[i-1], sortedRatings[i])
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        XCTAssertNil(tourViewModel.errorMessage)
        
        // Simulate an error
        let testError = "Failed to load tours"
        tourViewModel.errorMessage = testError
        
        XCTAssertEqual(tourViewModel.errorMessage, testError)
    }
    
    func testClearError() {
        tourViewModel.errorMessage = "Some error"
        XCTAssertNotNil(tourViewModel.errorMessage)
        
        tourViewModel.clearError()
        
        XCTAssertNil(tourViewModel.errorMessage)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState() {
        XCTAssertFalse(tourViewModel.isLoading)
        
        tourViewModel.isLoading = true
        XCTAssertTrue(tourViewModel.isLoading)
        
        tourViewModel.isLoading = false
        XCTAssertFalse(tourViewModel.isLoading)
    }
    
    // MARK: - Publisher Tests
    
    func testToursPublisher() {
        let expectation = XCTestExpectation(description: "tours publisher")
        var receivedTourCounts: [Int] = []
        
        tourViewModel.$tours
            .map { $0.count }
            .sink { count in
                receivedTourCounts.append(count)
                if receivedTourCounts.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        tourViewModel.tours = testTours
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedTourCounts[0], 0) // Initial empty state
        XCTAssertEqual(receivedTourCounts[1], testTours.count) // After loading
    }
    
    func testFilteredToursPublisher() {
        let expectation = XCTestExpectation(description: "filteredTours publisher")
        var receivedCounts: [Int] = []
        
        tourViewModel.$filteredTours
            .map { $0.count }
            .sink { count in
                receivedCounts.append(count)
                if receivedCounts.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        tourViewModel.tours = testTours
        tourViewModel.applyFilters()
        
        // Apply a filter
        tourViewModel.selectedCategory = .historical
        tourViewModel.applyFilters()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedCounts[0], 0) // Initial empty state
        XCTAssertTrue(receivedCounts.count >= 2)
    }
    
    func testSearchTextPublisher() {
        let expectation = XCTestExpectation(description: "searchText publisher")
        var receivedSearchTexts: [String] = []
        
        tourViewModel.$searchText
            .sink { text in
                receivedSearchTexts.append(text)
                if receivedSearchTexts.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        tourViewModel.searchText = "Historical"
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedSearchTexts[0], "") // Initial empty state
        XCTAssertEqual(receivedSearchTexts[1], "Historical") // After update
    }
    
    // MARK: - Filter Reset Tests
    
    func testResetFilters() {
        tourViewModel.tours = testTours
        
        // Set some filters
        tourViewModel.searchText = "Historical"
        tourViewModel.selectedCategory = .nature
        tourViewModel.selectedDifficulty = .difficult
        tourViewModel.selectedTourType = .driving
        tourViewModel.sortOption = .duration
        
        // Reset filters
        tourViewModel.resetFilters()
        
        XCTAssertEqual(tourViewModel.searchText, "")
        XCTAssertEqual(tourViewModel.selectedCategory, .all)
        XCTAssertEqual(tourViewModel.selectedDifficulty, .all)
        XCTAssertEqual(tourViewModel.selectedTourType, .all)
        XCTAssertEqual(tourViewModel.sortOption, .name)
        
        // Filtered tours should show all tours after reset
        XCTAssertEqual(tourViewModel.filteredTours.count, testTours.count)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetFiltering() {
        // Create a large dataset
        var largeTourSet: [Tour] = []
        for i in 0..<1000 {
            let tour = TestDataFactory.createTour(
                name: "Tour \(i)",
                category: TourCategory.allCases.randomElement() ?? .general,
                difficulty: TourDifficulty.allCases.randomElement() ?? .easy
            )
            largeTourSet.append(tour)
        }
        
        tourViewModel.tours = largeTourSet
        
        measure {
            tourViewModel.searchText = "Tour 1"
            tourViewModel.applyFilters()
        }
        
        XCTAssertGreaterThan(tourViewModel.filteredTours.count, 0)
    }
    
    func testFilteringPerformance() {
        tourViewModel.tours = Array(repeating: testTours, count: 100).flatMap { $0 }
        
        measure {
            for category in [TourCategoryFilter.historical, .nature, .architecture] {
                tourViewModel.selectedCategory = category
                tourViewModel.applyFilters()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyToursList() {
        tourViewModel.tours = []
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.isEmpty)
    }
    
    func testFilterWithNoMatchingTours() {
        tourViewModel.tours = testTours
        tourViewModel.selectedCategory = .cultural // None of our test tours are cultural
        tourViewModel.applyFilters()
        
        XCTAssertTrue(tourViewModel.filteredTours.isEmpty)
    }
    
    func testSpecialCharactersInSearch() {
        let specialTour = TestDataFactory.createTour(
            name: "Café & Résumé Tour: 50% off!",
            description: "Special chars: @#$%^&*()"
        )
        
        tourViewModel.tours = [specialTour]
        
        // Test searching for special characters
        tourViewModel.searchText = "Café"
        tourViewModel.applyFilters()
        
        XCTAssertEqual(tourViewModel.filteredTours.count, 1)
        XCTAssertEqual(tourViewModel.filteredTours.first?.name, specialTour.name)
    }
}