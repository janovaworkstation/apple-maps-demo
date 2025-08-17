import UIKit
import Combine
import SwiftUI

// MARK: - ImageCacheManager

@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    // MARK: - Cache Configuration
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache: DiskImageCache
    private let maxMemoryMB: Int = 50
    private let maxDiskMB: Int = 200
    private let compressionQuality: CGFloat = 0.8
    
    // MARK: - State Tracking
    @Published private(set) var cacheStatistics = ImageCacheStatistics()
    private var cancellables = Set<AnyCancellable>()
    private let processingQueue = DispatchQueue(label: "image-cache", qos: .utility)
    private var memoryCacheCount: Int = 0
    
    // MARK: - Memory Pressure Handling
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Initialization
    
    private init() {
        self.diskCache = DiskImageCache()
        setupMemoryCache()
        setupMemoryPressureHandling()
        print("🖼️ ImageCacheManager initialized")
    }
    
    private func setupMemoryCache() {
        memoryCache.totalCostLimit = maxMemoryMB * 1024 * 1024 // Convert MB to bytes
        memoryCache.countLimit = 100 // Maximum number of images
        memoryCache.evictsObjectsWithDiscardedContent = true
        
        // Note: NSCache delegate is not used in this implementation 
        // due to Swift 6 safety requirements. Cache count is managed manually.
    }
    
    private func setupMemoryPressureHandling() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource?.resume()
    }
    
    deinit {
        memoryPressureSource?.cancel()
        cancellables.removeAll()
        print("🧹 ImageCacheManager cleanup completed")
    }
    
    // MARK: - Public Interface
    
    /// Load image with caching and compression
    func loadImage(for poi: PointOfInterest, size: ImageSize = .medium) async -> UIImage? {
        let cacheKey = buildCacheKey(poiId: poi.id, size: size)
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            updateStatistics(hit: true, source: .memory)
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = await diskCache.loadImage(for: cacheKey) {
            // Store in memory cache for faster access
            let cost = estimateImageMemoryCost(diskImage)
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: cost)
            memoryCacheCount += 1
            updateStatistics(hit: true, source: .disk)
            return diskImage
        }
        
        // Load and process new image
        if let newImage = await loadAndProcessImage(for: poi, size: size) {
            await cacheImage(newImage, for: cacheKey)
            updateStatistics(hit: false, source: .network)
            return newImage
        }
        
        updateStatistics(hit: false, source: .none)
        return nil
    }
    
    /// Create optimized artwork for Now Playing
    func createOptimizedArtwork(for poi: PointOfInterest) async -> UIImage? {
        let artworkSize = ImageSize.artwork
        return await loadImage(for: poi, size: artworkSize)
    }
    
    /// Create compressed POI marker image
    func createPOIMarkerImage(for poi: PointOfInterest, isVisited: Bool, isActive: Bool) -> UIImage? {
        let cacheKey = "marker_\(poi.id)_\(isVisited)_\(isActive)"
        
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        let markerImage = generatePOIMarkerImage(
            category: poi.category,
            isVisited: isVisited,
            isActive: isActive
        )
        
        if let image = markerImage {
            let cost = estimateImageMemoryCost(image)
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
            memoryCacheCount += 1
        }
        
        return markerImage
    }
    
    // MARK: - Cache Management
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        memoryCacheCount = 0
        updateCacheStatistics()
        print("🧹 Memory cache cleared")
    }
    
    func clearDiskCache() async {
        await diskCache.clearCache()
        updateCacheStatistics()
        print("🧹 Disk cache cleared")
    }
    
    func clearAllCaches() async {
        clearMemoryCache()
        await clearDiskCache()
        print("🧹 All image caches cleared")
    }
    
    func optimizeCache() async {
        await diskCache.optimizeCache()
        updateCacheStatistics()
        print("⚡ Image cache optimized")
    }
    
    // MARK: - Private Methods
    
    private func buildCacheKey(poiId: UUID, size: ImageSize) -> String {
        return "\(poiId.uuidString)_\(size.rawValue)"
    }
    
    private func loadAndProcessImage(for poi: PointOfInterest, size: ImageSize) async -> UIImage? {
        // For now, generate a placeholder image
        // In a real app, this would load from URL or assets
        return generatePlaceholderImage(for: poi, size: size)
    }
    
    private func generatePlaceholderImage(for poi: PointOfInterest, size: ImageSize) -> UIImage? {
        let imageSize = size.cgSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        return renderer.image { context in
            // Create gradient background based on POI category
            let colors = getCategoryColors(for: poi.category)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.primary.cgColor, colors.secondary.cgColor] as CFArray,
                locations: nil
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint.zero,
                end: CGPoint(x: imageSize.width, y: imageSize.height),
                options: []
            )
            
            // Add category icon
            let iconSize = imageSize.width * 0.4
            let iconRect = CGRect(
                x: (imageSize.width - iconSize) / 2,
                y: (imageSize.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.white.setFill()
            UIBezierPath(ovalIn: iconRect).fill()
        }
    }
    
    private func generatePOIMarkerImage(category: POICategory, isVisited: Bool, isActive: Bool) -> UIImage? {
        let size = CGSize(width: 30, height: 30)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let colors = getCategoryColors(for: category)
            let markerColor = isActive ? UIColor.orange : (isVisited ? UIColor.green : colors.primary)
            
            // Draw marker circle
            markerColor.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            
            // Draw inner icon
            UIColor.white.setFill()
            let iconSize: CGFloat = 16
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            UIBezierPath(ovalIn: iconRect).fill()
        }
    }
    
    private func getCategoryColors(for category: POICategory) -> (primary: UIColor, secondary: UIColor) {
        switch category {
        case .landmark, .monument:
            return (.systemBlue, .systemTeal)
        case .museum:
            return (.systemPurple, .systemIndigo)
        case .restaurant:
            return (.systemRed, .systemOrange)
        case .shop:
            return (.systemOrange, .systemYellow)
        case .park, .viewpoint:
            return (.systemGreen, .systemMint)
        case .building:
            return (.systemGray, .systemGray2)
        case .general:
            return (.systemBlue, .systemCyan)
        }
    }
    
    private func cacheImage(_ image: UIImage, for cacheKey: String) async {
        // Store in memory cache
        let cost = estimateImageMemoryCost(image)
        memoryCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
        memoryCacheCount += 1
        
        // Store compressed version in disk cache
        if let compressedData = compressImage(image) {
            await diskCache.storeImage(data: compressedData, for: cacheKey)
        }
    }
    
    private func compressImage(_ image: UIImage) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }
    
    private func estimateImageMemoryCost(_ image: UIImage) -> Int {
        let bytesPerPixel = 4 // RGBA
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return width * height * bytesPerPixel
    }
    
    private func handleMemoryPressure() {
        print("⚠️ Memory pressure detected - clearing image cache")
        clearMemoryCache()
    }
    
    private func updateStatistics(hit: Bool, source: CacheSource) {
        if hit {
            cacheStatistics.hitCount += 1
        } else {
            cacheStatistics.missCount += 1
        }
        
        switch source {
        case .memory:
            cacheStatistics.memoryHits += 1
        case .disk:
            cacheStatistics.diskHits += 1
        case .network:
            cacheStatistics.networkLoads += 1
        case .none:
            break
        }
    }
    
    private func updateCacheStatistics() {
        Task {
            let diskStats = await diskCache.getStatistics()
            cacheStatistics.diskSizeBytes = diskStats.totalSize
            cacheStatistics.diskItems = diskStats.itemCount
            cacheStatistics.memorySizeBytes = estimateMemoryCacheSize()
            cacheStatistics.memoryItems = memoryCacheCount
        }
    }
    
    private func estimateMemoryCacheSize() -> Int64 {
        // Since NSCache doesn't expose current size, estimate based on count and average image size
        let averageImageSize: Int64 = 50 * 1024 // Estimate 50KB per image
        return Int64(memoryCacheCount) * averageImageSize
    }
}

// MARK: - Supporting Types

enum ImageSize: String, CaseIterable {
    case small = "small"      // 64x64
    case medium = "medium"    // 128x128  
    case large = "large"      // 256x256
    case artwork = "artwork"  // 512x512
    
    var cgSize: CGSize {
        switch self {
        case .small: return CGSize(width: 64, height: 64)
        case .medium: return CGSize(width: 128, height: 128)
        case .large: return CGSize(width: 256, height: 256)
        case .artwork: return CGSize(width: 512, height: 512)
        }
    }
}

enum CacheSource {
    case memory, disk, network, none
}

struct ImageCacheStatistics {
    var hitCount: Int = 0
    var missCount: Int = 0
    var memoryHits: Int = 0
    var diskHits: Int = 0
    var networkLoads: Int = 0
    var memorySizeBytes: Int64 = 0
    var diskSizeBytes: Int64 = 0
    var memoryItems: Int = 0
    var diskItems: Int = 0
    
    var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
    
    var formattedMemorySize: String {
        ByteCountFormatter().string(fromByteCount: memorySizeBytes)
    }
    
    var formattedDiskSize: String {
        ByteCountFormatter().string(fromByteCount: diskSizeBytes)
    }
}

// MARK: - DiskImageCache

actor DiskImageCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxDiskSize: Int64 = 200 * 1024 * 1024 // 200MB
    
    init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsURL.appendingPathComponent("ImageCache")
        
        Task {
            await createCacheDirectory()
        }
    }
    
    private func createCacheDirectory() async {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create image cache directory: \(error)")
        }
    }
    
    func loadImage(for cacheKey: String) async -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    func storeImage(data: Data, for cacheKey: String) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to store image in disk cache: \(error)")
        }
    }
    
    func clearCache() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("❌ Failed to clear disk image cache: \(error)")
        }
    }
    
    func optimizeCache() async {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            )
            
            // Calculate total size
            var totalSize: Int64 = 0
            var fileInfos: [(url: URL, size: Int64, date: Date)] = []
            
            for fileURL in contents {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let size = Int64(resourceValues.fileSize ?? 0)
                let date = resourceValues.contentModificationDate ?? Date.distantPast
                
                totalSize += size
                fileInfos.append((url: fileURL, size: size, date: date))
            }
            
            // Remove oldest files if over size limit
            if totalSize > maxDiskSize {
                let sortedFiles = fileInfos.sorted { $0.date < $1.date }
                var sizeToRemove = totalSize - maxDiskSize + (maxDiskSize / 10) // Remove extra 10%
                
                for fileInfo in sortedFiles {
                    guard sizeToRemove > 0 else { break }
                    
                    try fileManager.removeItem(at: fileInfo.url)
                    sizeToRemove -= fileInfo.size
                }
            }
        } catch {
            print("❌ Failed to optimize disk image cache: \(error)")
        }
    }
    
    func getStatistics() async -> (totalSize: Int64, itemCount: Int) {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            var totalSize: Int64 = 0
            for fileURL in contents {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
            
            return (totalSize: totalSize, itemCount: contents.count)
        } catch {
            return (totalSize: 0, itemCount: 0)
        }
    }
}