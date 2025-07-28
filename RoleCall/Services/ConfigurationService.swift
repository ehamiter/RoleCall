//
//  ConfigurationService.swift
//  RoleCall
//
//  Created by Eric on 1/27/25.
//

import Foundation

class ConfigurationService {
    static let shared = ConfigurationService()
    
    private var config: [String: Any] = [:]
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("⚠️ Config.plist not found or invalid format")
            return
        }
        
        config = plist
        print("✅ Configuration loaded successfully")
    }
    
    func getValue(for key: String) -> String? {
        guard let value = config[key] as? String, !value.isEmpty else {
            print("⚠️ Configuration value for '\(key)' not found or empty")
            return nil
        }
        return value
    }
    
    // MARK: - TMDB Configuration
    
    var tmdbAPIKey: String? {
        return getValue(for: "TMDB_API_KEY")
    }
    
    var tmdbAccessToken: String? {
        return getValue(for: "TMDB_ACCESS_TOKEN")
    }
    
    var tmdbBaseURL: String? {
        return getValue(for: "TMDB_BASE_URL")
    }
    
    var tmdbImageBaseURL: String? {
        return getValue(for: "TMDB_IMAGE_BASE_URL")
    }
}