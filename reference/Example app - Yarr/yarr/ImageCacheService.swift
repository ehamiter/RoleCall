//
//  ImageCacheService.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation
import SwiftUI

@MainActor
class ImageCacheService: NSObject, ObservableObject, NSCacheDelegate {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, NSData>()
    private let diskCache: URL
    private let session: URLSession
    private var settings: SettingsModel?
    
    // Manual tracking of memory cache size for accurate reporting
    private var currentMemoryCacheSize: Int = 0
    
    // Default cache configuration (can be overridden by settings)
    private let defaultMaxMemoryCache = 100 * 1024 * 1024  // 100MB
    private let defaultMaxDiskCache = 500 * 1024 * 1024    // 500MB
    private let defaultCacheExpiration: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    
    private override init() {
        // Setup disk cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCache = cacheDirectory.appendingPathComponent("ImageCache")
        
        // Configure URLSession for image downloads
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20MB for URL cache
            diskCapacity: 100 * 1024 * 1024,   // 100MB for URL cache
            directory: nil
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        
        super.init()
        
        // Configure memory cache with defaults (after super.init)
        memoryCache.totalCostLimit = defaultMaxMemoryCache
        memoryCache.countLimit = 200  // Maximum 200 images in memory
        memoryCache.delegate = self
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: diskCache, withIntermediateDirectories: true)
        
        // Clean up old cache files on init
        Task {
            await cleanupExpiredFiles()
        }
    }
    
    // MARK: - Settings Integration
    
    func updateSettings(_ settings: SettingsModel) {
        self.settings = settings
        updateCacheConfiguration()
    }
    
    private func updateCacheConfiguration() {
        guard let settings = settings else { return }
        
        // Update memory cache limit
        let maxMemoryCacheBytes = settings.maxImageCacheSizeMB * 1024 * 1024
        memoryCache.totalCostLimit = maxMemoryCacheBytes
    }
    
    private var isCacheEnabled: Bool {
        return settings?.enableImageCaching ?? true
    }
    
    private var cacheExpiration: TimeInterval {
        guard let settings = settings else { return defaultCacheExpiration }
        return TimeInterval(settings.imageCacheExpirationDays * 24 * 60 * 60)
    }
    
    private var maxDiskCache: Int {
        return settings?.maxImageCacheSizeMB ?? (defaultMaxDiskCache / (1024 * 1024)) * 1024 * 1024
    }
    
    // MARK: - Public Methods
    
    func cachedImage(for url: String) -> Data? {
        guard isCacheEnabled else { return nil }
        
        let key = cacheKey(for: url)
        
        // Check memory cache first
        if let data = memoryCache.object(forKey: key as NSString) {
            return data as Data
        }
        
        // Check disk cache
        let diskPath = diskCachePath(for: url)
        if FileManager.default.fileExists(atPath: diskPath.path),
           let data = try? Data(contentsOf: diskPath),
           !isFileExpired(at: diskPath) {
            
            // Add back to memory cache
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            currentMemoryCacheSize += data.count
            return data
        }
        
        return nil
    }
    
    func loadImage(from url: String) async throws -> Data {
        // Check cache first (only if enabled)
        if let cachedData = cachedImage(for: url) {
            #if DEBUG
            print("🗄️ ImageCache: Using cached image for URL: \(url) (size: \(cachedData.count) bytes)")
            #endif
            return cachedData
        }
        
        // Download from network
        guard let imageURL = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        #if DEBUG
        print("📡 ImageCache: Downloading image from URL: \(url)")
        #endif
        
        let (data, _) = try await session.data(from: imageURL)
        
        // Cache the downloaded data (only if caching is enabled)
        if isCacheEnabled {
            await cacheImage(data: data, for: url)
            #if DEBUG
            print("💾 ImageCache: Cached image (size: \(data.count) bytes) for URL: \(url)")
            #endif
        }
        
        return data
    }
    
    private func cacheImage(data: Data, for url: String) async {
        let key = cacheKey(for: url)
        
        // Store in memory cache
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        currentMemoryCacheSize += data.count
        
        // Store in disk cache
        let diskPath = diskCachePath(for: url)
        try? data.write(to: diskPath)
        
        // Check if we need to cleanup disk cache
        await cleanupDiskCacheIfNeeded()
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        currentMemoryCacheSize = 0
        
        try? FileManager.default.removeItem(at: diskCache)
        try? FileManager.default.createDirectory(at: diskCache, withIntermediateDirectories: true)
    }
    
    func removeImage(for url: String) {
        guard isCacheEnabled else { return }
        
        let key = cacheKey(for: url)
        
        // Remove from memory cache
        if let existingData = memoryCache.object(forKey: key as NSString) {
            currentMemoryCacheSize -= existingData.count
        }
        memoryCache.removeObject(forKey: key as NSString)
        
        // Remove from disk cache
        let diskPath = diskCachePath(for: url)
        try? FileManager.default.removeItem(at: diskPath)
    }
    
    func getCacheSize() -> (memorySize: Int, diskSize: Int) {
        let memorySize = getCurrentMemoryCacheSize()
        let diskSize = diskCacheSize()
        
        #if DEBUG
        print("📊 ImageCache: Current cache sizes - Memory: \(memorySize) bytes, Disk: \(diskSize) bytes")
        #endif
        
        return (memorySize, diskSize)
    }
    
    private func getCurrentMemoryCacheSize() -> Int {
        return currentMemoryCacheSize
    }
    
    // MARK: - NSCacheDelegate
    
    nonisolated func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // This is called on a background thread, so we need to be careful
        if let data = obj as? NSData {
            Task { @MainActor in
                currentMemoryCacheSize -= data.count
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func cacheKey(for url: String) -> String {
        return url.sha256
    }
    
    private func diskCachePath(for url: String) -> URL {
        let filename = cacheKey(for: url)
        return diskCache.appendingPathComponent(filename)
    }
    
    private func isFileExpired(at url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return true
        }
        
        return Date().timeIntervalSince(modificationDate) > cacheExpiration
    }
    
    private func cleanupExpiredFiles() async {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: diskCache, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        // Collect all URLs first to avoid async iteration issues
        let fileURLs = enumerator.compactMap { $0 as? URL }
        
        for fileURL in fileURLs {
            if isFileExpired(at: fileURL) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    private func diskCacheSize() -> Int {
        let fileManager = FileManager.default
        var totalSize = 0
        
        guard let enumerator = fileManager.enumerator(at: diskCache, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        // Collect all URLs first to avoid async iteration issues
        let fileURLs = enumerator.compactMap { $0 as? URL }
        
        for fileURL in fileURLs {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func cleanupDiskCacheIfNeeded() async {
        let currentSize = diskCacheSize()
        
        if currentSize > maxDiskCache {
            await cleanupOldestFiles(targetSize: maxDiskCache / 2)  // Clean to 50% of max
        }
    }
    
    private func cleanupOldestFiles(targetSize: Int) async {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: diskCache, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }
        
        var files: [(url: URL, date: Date, size: Int)] = []
        
        // Collect all URLs first to avoid async iteration issues
        let fileURLs = enumerator.compactMap { $0 as? URL }
        
        for fileURL in fileURLs {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = resourceValues.contentModificationDate,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            
            files.append((url: fileURL, date: modificationDate, size: fileSize))
        }
        
        // Sort by modification date (oldest first)
        files.sort { $0.date < $1.date }
        
        var currentSize = diskCacheSize()
        
        for file in files {
            if currentSize <= targetSize {
                break
            }
            
            try? fileManager.removeItem(at: file.url)
            currentSize -= file.size
        }
    }
}

// MARK: - String Extension for SHA256

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hashed = data.withUnsafeBytes { bytes in
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(data.count), &digest)
            return digest
        }
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto 