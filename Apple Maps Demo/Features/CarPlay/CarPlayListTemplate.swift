//
//  CarPlayListTemplate.swift
//  Apple Maps Demo
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CarPlay
import Combine

@MainActor
class CarPlayListTemplate: NSObject {
    
    // MARK: - Properties
    private var tourViewModel = TourViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    // Template
    private(set) var template: CPListTemplate
    
    // Delegate
    weak var delegate: CarPlayTemplateDelegate?
    
    // Current tours
    private var availableTours: [Tour] = []
    private var downloadedTours: [Tour] = []
    
    // MARK: - Initialization
    
    override init() {
        // Create the list template
        self.template = CPListTemplate(title: "Audio Tours", sections: [])
        
        super.init()
        
        setupListTemplate()
        setupBindings()
        loadTours()
        
        print("📋 CarPlayListTemplate initialized")
    }
    
    deinit {
        cancellables.removeAll()
        print("🧹 CarPlayListTemplate cleaned up")
    }
    
    // MARK: - Setup
    
    private func setupListTemplate() {
        // Note: CPListTemplate.delegate is deprecated in iOS 14.0+
        // For iOS 14+, use CPListTemplateItem and handle selection via userInfo
        if #available(iOS 14.0, *) {
            // Use newer APIs when available
        } else {
            template.delegate = self
        }
        
        // Add navigation bar buttons
        setupNavigationButtons()
        
        // Initial empty state
        updateTemplateContent()
    }
    
    private func setupNavigationButtons() {
        // Back to map button
        let mapButton = CPBarButton(title: "Map") { [weak self] _ in
            // Dismiss this template to return to map
            self?.dismissTemplate()
        }
        
        template.leadingNavigationBarButtons = [mapButton]
        
        // Refresh button
        let refreshButton = CPBarButton(title: "Refresh") { [weak self] _ in
            self?.loadTours()
        }
        
        template.trailingNavigationBarButtons = [refreshButton]
    }
    
    private func setupBindings() {
        // Listen for tour updates
        tourViewModel.$tours
            .sink { [weak self] tours in
                self?.availableTours = tours
                self?.updateTemplateContent()
            }
            .store(in: &cancellables)
        
        tourViewModel.$isLoading
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.showLoadingState()
                } else {
                    self?.updateTemplateContent()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func refreshTours() {
        tourViewModel.refreshTours()
    }
    
    // MARK: - Private Methods
    
    private func loadTours() {
        tourViewModel.loadTours()
    }
    
    private func updateTemplateContent() {
        var sections: [CPListSection] = []
        
        // Filter downloaded tours
        downloadedTours = availableTours.filter { $0.isDownloaded }
        
        // Downloaded tours section
        if !downloadedTours.isEmpty {
            let downloadedSection = createDownloadedToursSection()
            sections.append(downloadedSection)
        }
        
        // Available tours section
        let availableSection = createAvailableToursSection()
        sections.append(availableSection)
        
        // Update template
        template.updateSections(sections)
    }
    
    private func createDownloadedToursSection() -> CPListSection {
        let items = downloadedTours.map { tour in
            createTourListItem(tour: tour, isDownloaded: true)
        }
        
        return CPListSection(items: items, header: "Downloaded Tours", sectionIndexTitle: nil)
    }
    
    private func createAvailableToursSection() -> CPListSection {
        let availableToursOnly = availableTours.filter { !$0.isDownloaded }
        
        let items = availableToursOnly.map { tour in
            createTourListItem(tour: tour, isDownloaded: false)
        }
        
        let header = downloadedTours.isEmpty ? "Available Tours" : "More Tours"
        return CPListSection(items: items, header: header, sectionIndexTitle: nil)
    }
    
    private func createTourListItem(tour: Tour, isDownloaded: Bool) -> CPListItem {
        let item = CPListItem(
            text: tour.name,
            detailText: createTourDetailText(tour: tour, isDownloaded: isDownloaded),
            image: createTourIcon(tour: tour, isDownloaded: isDownloaded),
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        
        // Store tour reference for selection handling
        item.userInfo = ["tour": tour]
        
        return item
    }
    
    private func createTourDetailText(tour: Tour, isDownloaded: Bool) -> String {
        var details: [String] = []
        
        // Duration
        let duration = formatDuration(tour.estimatedDuration)
        details.append(duration)
        
        // POI count
        details.append("\(tour.pointsOfInterest.count) stops")
        
        // Tour type
        details.append(tour.tourType.rawValue)
        
        // Download status
        if isDownloaded {
            details.append("Downloaded")
        } else {
            details.append("Requires download")
        }
        
        return details.joined(separator: " • ")
    }
    
    private func createTourIcon(tour: Tour, isDownloaded: Bool) -> UIImage? {
        // Create a colored icon based on tour category and download status
        let systemName = tour.category.carPlayIconName
        let color: UIColor = isDownloaded ? .systemGreen : .systemBlue
        
        return UIImage(systemName: systemName)?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func showLoadingState() {
        let loadingItem = CPListItem(
            text: "Loading tours...",
            detailText: "Please wait",
            image: UIImage(systemName: "arrow.clockwise"),
            accessoryImage: nil,
            accessoryType: .none
        )
        
        let loadingSection = CPListSection(items: [loadingItem])
        template.updateSections([loadingSection])
    }
    
    private func dismissTemplate() {
        // This would be handled by the interface controller
        // For now, we'll just notify the delegate
        print("📋 Dismissing CarPlay list template")
    }
    
    private func handleTourSelection(_ tour: Tour) {
        if tour.isDownloaded {
            // Start the tour immediately
            delegate?.carPlayTemplateDidSelectTour(tour)
        } else {
            // Show download confirmation
            showDownloadConfirmation(for: tour)
        }
    }
    
    private func showDownloadConfirmation(for tour: Tour) {
        // Create action sheet for download confirmation
        let downloadAction = CPAlertAction(title: "Download & Start", style: .default) { [weak self] _ in
            self?.downloadAndStartTour(tour)
        }
        
        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { _ in
            // Do nothing
        }
        
        let _ = CPActionSheetTemplate(
            title: "Download Required",
            message: "This tour needs to be downloaded before it can be started. Download now?",
            actions: [downloadAction, cancelAction]
        )
        
        // Present the alert (this would be handled by the interface controller)
        print("📋 Would show download confirmation for: \(tour.name)")
    }
    
    private func downloadAndStartTour(_ tour: Tour) {
        // Start download process
        Task {
            // This would integrate with the download system
            print("📥 Starting download for tour: \(tour.name)")
            
            // Simulate download (in real implementation, use DownloadManager)
            // await downloadManager.downloadTour(tour)
            
            // Start the tour after download
            delegate?.carPlayTemplateDidSelectTour(tour)
        }
    }
}

// MARK: - CPListTemplateDelegate

@available(iOS, deprecated: 14.0, message: "Use CPListTemplateItem with handlers instead")
extension CarPlayListTemplate: CPListTemplateDelegate {
    
    nonisolated func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void) {
        // Handle tour selection
        guard let tourInfo = item.userInfo as? [String: Any],
              let tour = tourInfo["tour"] as? Tour else {
            completionHandler()
            return
        }
        
        Task { @MainActor in
            handleTourSelection(tour)
            completionHandler()
        }
    }
}

// MARK: - Supporting Extensions

private extension TourCategory {
    var carPlayIconName: String {
        switch self {
        case .historical:
            return "building.columns"
        case .cultural:
            return "theatermasks"
        case .nature:
            return "leaf"
        case .architecture:
            return "building"
        case .foodAndDrink:
            return "fork.knife"
        case .general:
            return "map"
        }
    }
}