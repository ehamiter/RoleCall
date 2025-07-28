//
//  PlexService.swift
//  They Were Also In This
//
//  Created by Eric on 7/28/25.
//

import Foundation
import Combine

@MainActor
class PlexService: ObservableObject {
    @Published var settings = PlexSettings()
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var serverCapabilities: PlexCapabilitiesResponse?

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "PlexSettings"

    init() {
        loadSettings()
        checkTokenValidity()
    }

    // MARK: - Settings Management
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(PlexSettings.self, from: data) {
            self.settings = settings
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    func updateServerIP(_ ip: String) {
        settings.serverIP = ip
        saveSettings()
    }

    // MARK: - Authentication
    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await authenticateWithPlex(username: username, password: password)
            settings.plexToken = token
            settings.tokenExpirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) // Assume 30-day validity
            saveSettings()
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func authenticateWithPlex(username: String, password: String) async throws -> String {
        guard let url = URL(string: "https://plex.tv/users/sign_in.json") else {
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("They Were Also In This iOS App", forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("They Were Also In This", forHTTPHeaderField: "X-Plex-Product")
        request.setValue("1.0", forHTTPHeaderField: "X-Plex-Version")
        request.setValue("iOS", forHTTPHeaderField: "X-Plex-Platform")
        request.setValue("18.5", forHTTPHeaderField: "X-Plex-Platform-Version")
        request.setValue("mobile", forHTTPHeaderField: "X-Plex-Device")

        // Create the correct JSON payload format for Plex
        let loginPayload = [
            "user": [
                "login": username,
                "password": password
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: loginPayload, options: [])
            request.httpBody = jsonData

            print("🔐 Attempting Plex authentication...")
            print("📍 URL: \(url)")
            print("📦 Payload: \(String(data: jsonData, encoding: .utf8) ?? "nil")")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw PlexError.invalidResponse
            }

            print("📊 Response status: \(httpResponse.statusCode)")
            print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            if httpResponse.statusCode == 401 {
                throw PlexError.invalidCredentials
            }

            if httpResponse.statusCode == 422 {
                // Handle validation errors
                if let errorResponse = try? JSONDecoder().decode(PlexErrorResponse.self, from: data) {
                    let errorMessage = errorResponse.errors.map { $0.message }.joined(separator: ", ")
                    throw PlexError.validationError(errorMessage)
                }
                throw PlexError.invalidCredentials
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                throw PlexError.serverError(httpResponse.statusCode)
            }

            let authResponse = try JSONDecoder().decode(PlexAuthResponse.self, from: data)
            print("✅ Authentication successful, token received")
            return authResponse.user.authToken

        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw PlexError.invalidResponse
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }

    func checkTokenValidity() {
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            isLoggedIn = false
            return
        }

        // If we have both IP and token, consider logged in
        isLoggedIn = true

        // Then verify the token works by calling server capabilities
        Task {
            do {
                _ = try await getServerCapabilities()
                // Token is valid, keep logged in status
            } catch {
                // Token is invalid, log out
                await MainActor.run {
                    isLoggedIn = false
                    settings.plexToken = ""
                    settings.tokenExpirationDate = nil
                    saveSettings()
                }
            }
        }
    }

    func logout() {
        settings.plexToken = ""
        settings.tokenExpirationDate = nil
        saveSettings()
        isLoggedIn = false
        serverCapabilities = nil
    }

    // MARK: - Server Capabilities
    func getServerCapabilities() async throws -> PlexCapabilitiesResponse {
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        let urlString = "http://\(settings.serverIP):32400/?X-Plex-Token=\(settings.plexToken)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // 10 second timeout

        print("🏠 Checking server capabilities...")
        print("📍 URL: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw PlexError.invalidResponse
            }

            print("📊 Server response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                print("❌ Server returned 401 - Token invalid or expired")
                throw PlexError.invalidToken
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Server error: \(httpResponse.statusCode)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw PlexError.serverError(httpResponse.statusCode)
            }

            print("✅ Server capabilities received successfully")
            print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            let capabilities = try JSONDecoder().decode(PlexCapabilitiesResponse.self, from: data)
            await MainActor.run {
                self.serverCapabilities = capabilities
            }
            return capabilities

        } catch let error as PlexError {
            throw error
        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw PlexError.invalidResponse
        } catch {
            print("❌ Network error: \(error)")
            throw PlexError.invalidResponse
        }
    }

    func fetchServerCapabilities() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getServerCapabilities()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Plex Errors
enum PlexError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCredentials
    case invalidToken
    case notAuthenticated
    case validationError(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidCredentials:
            return "Invalid username or password"
        case .invalidToken:
            return "Invalid or expired token"
        case .notAuthenticated:
            return "Not authenticated. Please log in first."
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}