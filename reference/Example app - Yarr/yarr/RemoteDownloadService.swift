//
//  RemoteDownloadService.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation

@MainActor
class RemoteDownloadService: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: String = ""
    @Published var lastError: String?
    
    private let settings: SettingsModel
    
    init(settings: SettingsModel) {
        self.settings = settings
    }
    
    enum DownloadError: Error, LocalizedError {
        case invalidSettings
        case remoteDownloadFailed(String)
        case sshConnectionFailed(String)
        case fileNotFound
        case invalidTorrentURL
        
        var errorDescription: String? {
            switch self {
            case .invalidSettings:
                return "SSH settings are not properly configured"
            case .remoteDownloadFailed(let message):
                return "Failed to download torrent file on remote server: \(message)"
            case .sshConnectionFailed(let message):
                return "Failed to connect via SSH: \(message)"
            case .fileNotFound:
                return "Downloaded torrent file not found on remote server"
            case .invalidTorrentURL:
                return "Invalid torrent URL"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func downloadAndTransferTorrent(_ torrent: Torrent) async throws {
        guard settings.isValid else {
            throw DownloadError.invalidSettings
        }
        
        guard !torrent.url.isEmpty else {
            throw DownloadError.invalidTorrentURL
        }
        
        isDownloading = true
        lastError = nil
        
        do {
            downloadProgress = "Downloading torrent file directly to remote server..."
            print("🚀 Starting remote download for torrent: \(torrent.quality) - \(torrent.size)")
            
            // Download torrent file directly to remote server via SSH + curl
            try await downloadTorrentDirectlyToRemote(url: torrent.url, hash: torrent.hash)
            
            downloadProgress = "Download completed successfully!"
            print("✅ Remote download completed successfully")
            
        } catch {
            lastError = error.localizedDescription
            print("❌ Remote download failed: \(error.localizedDescription)")
            throw error
        }
        
        isDownloading = false
    }
    
    // MARK: - Private Methods
    
    private func downloadTorrentDirectlyToRemote(url: String, hash: String) async throws {
        guard URL(string: url) != nil else {
            throw DownloadError.invalidTorrentURL
        }
        
        let sshHost = "\(settings.sshUsername)@\(settings.sshHostname)"
        let remoteTorrentPath = "\(settings.remoteWatchDirectory)/\(hash).torrent"
        
        // Construct the remote curl command
        let remoteCurlCommand = """
        /usr/bin/curl -L -o '\(remoteTorrentPath)' \
        -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' \
        '\(url)' && \
        echo "DOWNLOAD_SUCCESS: $(stat -c%s '\(remoteTorrentPath)' 2>/dev/null || stat -f%z '\(remoteTorrentPath)' 2>/dev/null || echo 0)"
        """
        
        // Execute SSH command
        let sshProcess = Process()
        sshProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        
        var arguments = [
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=30"
        ]
        
        // Add custom port if specified
        if settings.useCustomPort && settings.sshPort != 22 {
            arguments.append(contentsOf: ["-p", String(settings.sshPort)])
        }
        
        arguments.append(contentsOf: [sshHost, remoteCurlCommand])
        sshProcess.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        sshProcess.standardOutput = outputPipe
        sshProcess.standardError = errorPipe
        
        do {
            try sshProcess.run()
            sshProcess.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            if sshProcess.terminationStatus != 0 {
                let errorMessage = errorOutput.isEmpty ? "SSH command failed with exit code \(sshProcess.terminationStatus)" : errorOutput
                throw DownloadError.sshConnectionFailed(errorMessage)
            }
            
            // Parse the output to check if download was successful
            if output.contains("DOWNLOAD_SUCCESS:") {
                let components = output.components(separatedBy: "DOWNLOAD_SUCCESS: ")
                if components.count > 1 {
                    let sizeString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let fileSize = Int(sizeString), fileSize > 0 {
                        print("✅ Successfully downloaded torrent file: \(fileSize) bytes to \(sshHost):\(remoteTorrentPath)")
                        return
                    }
                }
            }
            
            // If we get here, the download likely failed
            let errorMessage = errorOutput.isEmpty ? "Remote download failed - file may be empty or curl command failed" : errorOutput
            throw DownloadError.remoteDownloadFailed(errorMessage)
            
        } catch let error as DownloadError {
            throw error
        } catch {
            throw DownloadError.sshConnectionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Test Connection
    
    func testConnection() async throws -> Bool {
        guard settings.isValid else {
            throw DownloadError.invalidSettings
        }
        
        let sshHost = "\(settings.sshUsername)@\(settings.sshHostname)"
        
        let sshProcess = Process()
        sshProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        
        var arguments = [
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=10"
        ]
        
        if settings.useCustomPort && settings.sshPort != 22 {
            arguments.append(contentsOf: ["-p", String(settings.sshPort)])
        }
        
        arguments.append(contentsOf: [sshHost, "echo 'Connection successful'"])
        
        sshProcess.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        sshProcess.standardOutput = outputPipe
        sshProcess.standardError = errorPipe
        
        do {
            try sshProcess.run()
            sshProcess.waitUntilExit()
            
            return sshProcess.terminationStatus == 0
            
        } catch {
            throw DownloadError.sshConnectionFailed(error.localizedDescription)
        }
    }
} 