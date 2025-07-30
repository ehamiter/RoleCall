//
//  SettingsModel.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation

@MainActor
class SettingsModel: ObservableObject {
    @Published var sshUsername: String = ""
    @Published var sshHostname: String = ""
    @Published var remoteWatchDirectory: String = ""
    @Published var sshPort: Int = 22
    @Published var useCustomPort: Bool = false
    
    // Cache settings
    @Published var enableImageCaching: Bool = true
    @Published var enableAPIResponseCaching: Bool = true
    @Published var imageCacheExpirationDays: Int = 7
    @Published var apiCacheTimeoutMinutes: Int = 5
    @Published var maxImageCacheSizeMB: Int = 500
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let sshUsername = "ssh_username"
        static let sshHostname = "ssh_hostname"
        static let remoteWatchDirectory = "remote_watch_directory"
        static let sshPort = "ssh_port"
        static let useCustomPort = "use_custom_port"
        
        // Cache keys
        static let enableImageCaching = "enable_image_caching"
        static let enableAPIResponseCaching = "enable_api_response_caching"
        static let imageCacheExpirationDays = "image_cache_expiration_days"
        static let apiCacheTimeoutMinutes = "api_cache_timeout_minutes"
        static let maxImageCacheSizeMB = "max_image_cache_size_mb"
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        sshUsername = userDefaults.string(forKey: Keys.sshUsername) ?? ""
        sshHostname = userDefaults.string(forKey: Keys.sshHostname) ?? ""
        remoteWatchDirectory = userDefaults.string(forKey: Keys.remoteWatchDirectory) ?? ""
        sshPort = userDefaults.integer(forKey: Keys.sshPort) == 0 ? 22 : userDefaults.integer(forKey: Keys.sshPort)
        useCustomPort = userDefaults.bool(forKey: Keys.useCustomPort)
        
        // Load cache settings with defaults
        enableImageCaching = userDefaults.object(forKey: Keys.enableImageCaching) == nil ? true : userDefaults.bool(forKey: Keys.enableImageCaching)
        enableAPIResponseCaching = userDefaults.object(forKey: Keys.enableAPIResponseCaching) == nil ? true : userDefaults.bool(forKey: Keys.enableAPIResponseCaching)
        imageCacheExpirationDays = userDefaults.integer(forKey: Keys.imageCacheExpirationDays) == 0 ? 7 : userDefaults.integer(forKey: Keys.imageCacheExpirationDays)
        apiCacheTimeoutMinutes = userDefaults.integer(forKey: Keys.apiCacheTimeoutMinutes) == 0 ? 5 : userDefaults.integer(forKey: Keys.apiCacheTimeoutMinutes)
        maxImageCacheSizeMB = userDefaults.integer(forKey: Keys.maxImageCacheSizeMB) == 0 ? 500 : userDefaults.integer(forKey: Keys.maxImageCacheSizeMB)
    }
    
    func saveSettings() {
        userDefaults.set(sshUsername, forKey: Keys.sshUsername)
        userDefaults.set(sshHostname, forKey: Keys.sshHostname)
        userDefaults.set(remoteWatchDirectory, forKey: Keys.remoteWatchDirectory)
        userDefaults.set(sshPort, forKey: Keys.sshPort)
        userDefaults.set(useCustomPort, forKey: Keys.useCustomPort)
        
        // Save cache settings
        userDefaults.set(enableImageCaching, forKey: Keys.enableImageCaching)
        userDefaults.set(enableAPIResponseCaching, forKey: Keys.enableAPIResponseCaching)
        userDefaults.set(imageCacheExpirationDays, forKey: Keys.imageCacheExpirationDays)
        userDefaults.set(apiCacheTimeoutMinutes, forKey: Keys.apiCacheTimeoutMinutes)
        userDefaults.set(maxImageCacheSizeMB, forKey: Keys.maxImageCacheSizeMB)
    }
    
    func resetToDefaults() {
        sshUsername = ""
        sshHostname = ""
        remoteWatchDirectory = ""
        sshPort = 22
        useCustomPort = false
        
        // Reset cache settings to defaults
        enableImageCaching = true
        enableAPIResponseCaching = true
        imageCacheExpirationDays = 7
        apiCacheTimeoutMinutes = 5
        maxImageCacheSizeMB = 500
        
        saveSettings()
    }
    
    func clearAllSettings() {
        userDefaults.removeObject(forKey: Keys.sshUsername)
        userDefaults.removeObject(forKey: Keys.sshHostname)
        userDefaults.removeObject(forKey: Keys.remoteWatchDirectory)
        userDefaults.removeObject(forKey: Keys.sshPort)
        userDefaults.removeObject(forKey: Keys.useCustomPort)
        
        // Clear cache settings
        userDefaults.removeObject(forKey: Keys.enableImageCaching)
        userDefaults.removeObject(forKey: Keys.enableAPIResponseCaching)
        userDefaults.removeObject(forKey: Keys.imageCacheExpirationDays)
        userDefaults.removeObject(forKey: Keys.apiCacheTimeoutMinutes)
        userDefaults.removeObject(forKey: Keys.maxImageCacheSizeMB)
        
        loadSettings()
    }
    
    // MARK: - Cache Management Methods
    
    func clearImageCache() async {
        ImageCacheService.shared.clearCache()
    }
    
    func getCacheInfo() -> (imageCacheSize: String, apiCacheInfo: String) {
        let cacheSize = ImageCacheService.shared.getCacheSize()
        let diskSizeString = formatBytes(cacheSize.diskSize)
        let memorySizeString = formatBytes(cacheSize.memorySize)
        
        // Combine memory and disk cache sizes for display
        let imageSizeString = "Memory: \(memorySizeString), Disk: \(diskSizeString)"
        
        let apiCacheInfo = enableAPIResponseCaching ? "Enabled (timeout: \(apiCacheTimeoutMinutes)m)" : "Disabled"
        
        return (imageCacheSize: imageSizeString, apiCacheInfo: apiCacheInfo)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Computed Properties
    
    var isValid: Bool {
        return !sshUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !sshHostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !remoteWatchDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               sshPort > 0 && sshPort <= 65535
    }
    
    var sshConnectionString: String {
        let port = useCustomPort ? sshPort : 22
        return port == 22 ? "\(sshUsername)@\(sshHostname)" : "\(sshUsername)@\(sshHostname):\(port)"
    }
    
    var fullRemotePath: String {
        return "\(sshConnectionString):\(remoteWatchDirectory)"
    }
} 