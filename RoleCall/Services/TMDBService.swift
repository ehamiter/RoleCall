//
//  TMDBService.swift
//  RoleCall
//
//  Created by Eric on 1/27/25.
//

import Foundation

@MainActor
class TMDBService: ObservableObject {
    private var baseURL: String
    private var accessToken: String
    private var imageBaseURL: String
    private var isConfigurationLoaded = false
    private var configurationTask: Task<Void, Never>?

    init() {
        // Initialize with fallback values
        self.baseURL = "https://api.themoviedb.org/3"
        self.accessToken = ""
        self.imageBaseURL = "https://image.tmdb.org/t/p"

        // Start async configuration loading
        configurationTask = Task {
            await ensureConfigurationLoaded()
        }
    }

    private func ensureConfigurationLoaded() async {
        // Ensure ConfigurationService is initialized
        _ = ConfigurationService.shared

        // Try loading configuration with retries
        var attempts = 0
        let maxAttempts = 10

        while attempts < maxAttempts && !isConfigurationLoaded {
            await loadConfiguration()

            if isConfigurationLoaded {
                print("✅ TMDB Service configuration loaded successfully after \(attempts + 1) attempts")
                break
            }

            attempts += 1
            print("🔄 TMDB configuration attempt \(attempts)/\(maxAttempts), retrying in 100ms...")

            // Wait 100ms between attempts
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if !isConfigurationLoaded {
            print("❌ TMDB Service configuration failed after \(maxAttempts) attempts")
        }
    }

    private func loadConfiguration() async {
        let config = ConfigurationService.shared

        // Update configuration values
        self.baseURL = config.tmdbBaseURL ?? "https://api.themoviedb.org/3"
        self.accessToken = config.tmdbAccessToken ?? ""
        self.imageBaseURL = config.tmdbImageBaseURL ?? "https://image.tmdb.org/t/p"

        // Mark as configured if we have a valid token
        self.isConfigurationLoaded = !accessToken.isEmpty

        // Log configuration status
        if config.tmdbAccessToken == nil || config.tmdbAccessToken?.isEmpty == true {
            print("⚠️ TMDB Access Token not found in configuration")
        } else {
            print("✅ TMDB Service configured successfully with token: \(String(accessToken.prefix(20)))...")
        }
    }

    // MARK: - Public Methods

    /// Search for a person by name
    func searchPerson(name: String) async throws -> TMDBPersonSearchResponse {
        print("🔍 TMDB: Searching for person '\(name)'")

        let endpoint = "/search/person"
        let queryItems = [
            URLQueryItem(name: "query", value: name),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1")
        ]

        return try await performRequest(endpoint: endpoint, queryItems: queryItems, responseType: TMDBPersonSearchResponse.self)
    }

    /// Get detailed information about a person
    func getPersonDetails(personId: Int) async throws -> TMDBPersonDetails {
        let endpoint = "/person/\(personId)"
        let queryItems = [
            URLQueryItem(name: "language", value: "en-US")
        ]

        return try await performRequest(endpoint: endpoint, queryItems: queryItems, responseType: TMDBPersonDetails.self)
    }

    /// Get movie credits for a person
    func getPersonMovieCredits(personId: Int) async throws -> TMDBPersonMovieCredits {
        let endpoint = "/person/\(personId)/movie_credits"
        let queryItems = [
            URLQueryItem(name: "language", value: "en-US")
        ]

        return try await performRequest(endpoint: endpoint, queryItems: queryItems, responseType: TMDBPersonMovieCredits.self)
    }

    /// Search for a movie by title and optionally year
    func searchMovie(title: String, year: Int? = nil) async throws -> TMDBMovieSearchResponse {
        let endpoint = "/search/movie"
        var queryItems = [
            URLQueryItem(name: "query", value: title),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1")
        ]

        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }

        return try await performRequest(endpoint: endpoint, queryItems: queryItems, responseType: TMDBMovieSearchResponse.self)
    }

    /// Generate full URL for profile image
    func profileImageURL(path: String?, size: TMDBImageSize = .w500) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }

    /// Generate full URL for poster image
    func posterImageURL(path: String?, size: TMDBImageSize = .w342) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }

    // MARK: - Private Methods

    private func performRequest<T: Codable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        responseType: T.Type
    ) async throws -> T {
        // Ensure configuration is loaded before making any requests
        if !isConfigurationLoaded {
            print("🔄 TMDB Service not ready, waiting for configuration...")

            // Wait for the configuration task to complete
            await configurationTask?.value

            // If still not loaded, try one more time
            if !isConfigurationLoaded {
                await ensureConfigurationLoaded()
            }

            guard isConfigurationLoaded && !accessToken.isEmpty else {
                print("❌ TMDB Service configuration failed")
                throw TMDBError.missingConfiguration("TMDB Access Token not found in Config.plist. Please check your configuration.")
            }
        }

        print("✅ TMDB Service ready, making API request to \(endpoint)")

        guard let url = URL(string: baseURL + endpoint) else {
            throw TMDBError.invalidURL
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // Increased timeout to 30 seconds
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(accessToken)"
        ]

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TMDBError.invalidResponse
            }

            guard 200...299 ~= httpResponse.statusCode else {
                throw TMDBError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            return try decoder.decode(responseType, from: data)

        } catch {
            if error is TMDBError {
                throw error
            } else if error is DecodingError {
                print("TMDB Decoding error: \(error)")
                throw TMDBError.decodingError
            } else {
                print("TMDB Network error: \(error)")
                throw TMDBError.networkError
            }
        }
    }

    // MARK: - Debug Methods

    /// Get current configuration status for debugging
    func getConfigurationStatus() -> (isLoaded: Bool, hasToken: Bool, tokenPrefix: String) {
        return (
            isLoaded: isConfigurationLoaded,
            hasToken: !accessToken.isEmpty,
            tokenPrefix: accessToken.isEmpty ? "NO TOKEN" : String(accessToken.prefix(20)) + "..."
        )
    }
}

// MARK: - TMDB Image Sizes
enum TMDBImageSize: String {
    case w92 = "w92"
    case w154 = "w154"
    case w185 = "w185"
    case w342 = "w342"
    case w500 = "w500"
    case w780 = "w780"
    case original = "original"
}

// MARK: - TMDB Errors
enum TMDBError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case httpError(statusCode: Int)
    case missingConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .networkError:
            return "Network error"
        case .decodingError:
            return "Failed to decode response"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .missingConfiguration(let message):
            return "Configuration error: \(message)"
        }
    }
}