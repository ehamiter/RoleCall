//
//  SettingsView.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @Environment(\.dismiss) private var dismiss
    @State private var testingConnection = false
    @State private var connectionTestResult: String?
    @State private var clearingCache = false
    @State private var cacheInfo: (imageCacheSize: String, apiCacheInfo: String) = ("", "")
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    connectionSection
                    pathSection
                    cacheSection
                    advancedSection
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer buttons
            footer
        }
        .frame(width: 600, height: 550)  // Increased size for cache section
        .background(Color(.windowBackgroundColor))
        .onAppear {
            updateCacheInfo()
        }
    }
    
    // MARK: - View Components
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Configure remote torrent download and caching settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            // Security Notice
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Your credentials are stored securely on your device and never shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color(.controlBackgroundColor))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSH Connection")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("username", text: $settings.sshUsername)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hostname")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("hostname.com", text: $settings.sshHostname)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Connection string preview
                if !settings.sshUsername.isEmpty && !settings.sshHostname.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("Connection: \(settings.sshConnectionString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remote Path")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Watch Directory")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("/path/to/rtorrent/watch", text: $settings.remoteWatchDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Torrent files will be uploaded to this directory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Full path preview
                if settings.isValid {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("Full path: \(settings.fullRemotePath)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cache & Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                // Image caching settings
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable image caching", isOn: $settings.enableImageCaching)
                        .toggleStyle(.checkbox)
                        .onChange(of: settings.enableImageCaching) { oldValue, newValue in
                            updateCacheInfo()
                        }
                    
                    if settings.enableImageCaching {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cache expiration (days)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("7", value: $settings.imageCacheExpirationDays, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Max cache size (MB)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("500", value: $settings.maxImageCacheSizeMB, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                }
                                
                                Spacer()
                            }
                            .padding(.leading, 20)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("Current image cache size: \(cacheInfo.imageCacheSize)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Clear Cache") {
                                    clearImageCache()
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .disabled(clearingCache)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // API response caching settings
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable API response caching", isOn: $settings.enableAPIResponseCaching)
                        .toggleStyle(.checkbox)
                        .onChange(of: settings.enableAPIResponseCaching) { oldValue, newValue in
                            updateCacheInfo()
                        }
                    
                    if settings.enableAPIResponseCaching {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cache timeout (minutes)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("5", value: $settings.apiCacheTimeoutMinutes, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                }
                                
                                Spacer()
                            }
                            .padding(.leading, 20)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("API caching: \(cacheInfo.apiCacheInfo)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // Cache benefits info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Benefits of caching:")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Faster image loading and browsing")
                        Text("• Reduced bandwidth usage")
                        Text("• Better performance on slow connections")
                        Text("• Offline access to previously viewed content")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Use custom SSH port", isOn: $settings.useCustomPort)
                    .toggleStyle(.checkbox)
                
                if settings.useCustomPort {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SSH Port")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("22", value: $settings.sshPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                }
                
                // Connection status
                HStack(spacing: 8) {
                    Image(systemName: settings.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(settings.isValid ? .green : .red)
                        .font(.caption)
                    
                    Text(settings.isValid ? "Configuration is valid" : "Please fill in all required fields")
                        .font(.caption)
                        .foregroundColor(settings.isValid ? .green : .red)
                }
                .padding(.top, 8)
                
                // Test connection button and result
                if settings.isValid {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: testConnection) {
                            HStack(spacing: 6) {
                                if testingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text(testingConnection ? "Testing..." : "Test Connection")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .disabled(testingConnection)
                        
                        if let result = connectionTestResult {
                            HStack(spacing: 6) {
                                Image(systemName: result.contains("successful") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.contains("successful") ? .green : .red)
                                    .font(.caption)
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(result.contains("successful") ? .green : .red)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Settings management section
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Settings Management")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Reset to Defaults") {
                            settings.resetToDefaults()
                            updateCacheInfo()
                        }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                        
                        Button("Clear All Settings") {
                            settings.clearAllSettings()
                            updateCacheInfo()
                        }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                    
                    Text("Reset will restore default values. Clear will remove all saved settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button("Cancel") {
                settings.loadSettings() // Revert any unsaved changes
                dismiss()
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button("Save") {
                settings.saveSettings()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!settings.isValid)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Private Methods
    
    private func updateCacheInfo() {
        cacheInfo = settings.getCacheInfo()
    }
    
    private func clearImageCache() {
        clearingCache = true
        Task {
            await settings.clearImageCache()
            await MainActor.run {
                clearingCache = false
                updateCacheInfo()
            }
        }
    }
    
    private func testConnection() {
        testingConnection = true
        connectionTestResult = nil
        
        Task {
            let downloadService = RemoteDownloadService(settings: settings)
            
            do {
                let success = try await downloadService.testConnection()
                await MainActor.run {
                    connectionTestResult = success ? "Connection successful" : "Connection failed"
                    testingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = "Connection failed: \(error.localizedDescription)"
                    testingConnection = false
                }
            }
        }
    }
}

#Preview {
    SettingsView(settings: SettingsModel())
} 