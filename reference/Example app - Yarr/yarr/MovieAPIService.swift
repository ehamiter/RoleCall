//
//  MovieAPIService.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation

@MainActor
class MovieAPIService: ObservableObject {
    private let baseURL = "https://yts.mx/api/v2"
    private let session: URLSession
    private let settings: SettingsModel?
    
    // In-memory cache for API responses
    private var movieListCache: [String: (data: MovieListResult, timestamp: Date)] = [:]
    private var movieDetailsCache: [Int: (data: MovieDetails, timestamp: Date)] = [:]
    private var movieSuggestionsCache: [Int: (data: [Movie], timestamp: Date)] = [:]
    
    // Cache configuration
    private let maxCacheSize = 100 // Maximum items in each cache
    
    init(settings: SettingsModel? = nil) {
        self.settings = settings
        
        // Configure URLSession with caching for better performance
        let config = URLSessionConfiguration.default
        
        // Enable HTTP caching with generous limits
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50MB memory cache
            diskCapacity: 200 * 1024 * 1024,      // 200MB disk cache
            directory: nil
        )
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        // Optimize for better performance
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Cache Configuration
    
    private var cacheTimeout: TimeInterval {
        guard let settings = settings, settings.enableAPIResponseCaching else {
            return 0 // No caching if disabled
        }
        return TimeInterval(settings.apiCacheTimeoutMinutes * 60)
    }
    
    private var isCacheEnabled: Bool {
        return settings?.enableAPIResponseCaching ?? true
    }
    
    enum APIError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError(Error)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .decodingError(let error):
                return "Failed to decode data: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func cleanupCaches() {
        guard isCacheEnabled else {
            // Clear all caches if caching is disabled
            movieListCache.removeAll()
            movieDetailsCache.removeAll()
            movieSuggestionsCache.removeAll()
            return
        }
        
        let now = Date()
        let timeout = cacheTimeout
        
        // Clean movie list cache
        movieListCache = movieListCache.filter { 
            now.timeIntervalSince($0.value.timestamp) < timeout 
        }
        
        // Clean movie details cache
        movieDetailsCache = movieDetailsCache.filter { 
            now.timeIntervalSince($0.value.timestamp) < timeout 
        }
        
        // Clean suggestions cache
        movieSuggestionsCache = movieSuggestionsCache.filter { 
            now.timeIntervalSince($0.value.timestamp) < timeout 
        }
        
        // Limit cache sizes
        if movieListCache.count > maxCacheSize {
            let sortedKeys = movieListCache.keys.sorted { 
                movieListCache[$0]!.timestamp > movieListCache[$1]!.timestamp 
            }
            let keysToRemove = Array(sortedKeys.dropFirst(maxCacheSize))
            keysToRemove.forEach { movieListCache.removeValue(forKey: $0) }
        }
        
        if movieDetailsCache.count > maxCacheSize {
            let sortedKeys = movieDetailsCache.keys.sorted { 
                movieDetailsCache[$0]!.timestamp > movieDetailsCache[$1]!.timestamp 
            }
            let keysToRemove = Array(sortedKeys.dropFirst(maxCacheSize))
            keysToRemove.forEach { movieDetailsCache.removeValue(forKey: $0) }
        }
        
        if movieSuggestionsCache.count > maxCacheSize {
            let sortedKeys = movieSuggestionsCache.keys.sorted { 
                movieSuggestionsCache[$0]!.timestamp > movieSuggestionsCache[$1]!.timestamp 
            }
            let keysToRemove = Array(sortedKeys.dropFirst(maxCacheSize))
            keysToRemove.forEach { movieSuggestionsCache.removeValue(forKey: $0) }
        }
    }
    
    private func generateCacheKey(
        limit: Int,
        page: Int,
        quality: String?,
        minimumRating: Int,
        queryTerm: String?,
        genre: String?,
        sortBy: String,
        orderBy: String,
        withRTRatings: Bool
    ) -> String {
        let params = [
            "limit:\(limit)",
            "page:\(page)",
            "quality:\(quality ?? "nil")",
            "rating:\(minimumRating)",
            "query:\(queryTerm ?? "nil")",
            "genre:\(genre ?? "nil")",
            "sort:\(sortBy)",
            "order:\(orderBy)",
            "rt:\(withRTRatings)"
        ]
        let cacheKey = params.joined(separator: "|")
        
        #if DEBUG
        print("🔑 Generated cache key: '\(cacheKey)'")
        print("   - Query term: '\(queryTerm ?? "nil")'")
        #endif
        
        return cacheKey
    }
    
    // MARK: - Movie List with Caching
    
    func fetchMovies(
        limit: Int = 20,
        page: Int = 1,
        quality: String? = nil,
        minimumRating: Int = 0,
        queryTerm: String? = nil,
        genre: String? = nil,
        sortBy: String = "date_added",
        orderBy: String = "desc",
        withRTRatings: Bool = false
    ) async throws -> MovieListResult {
        // Clean up expired cache entries
        cleanupCaches()
        
        // Check cache first
        let cacheKey = generateCacheKey(
            limit: limit, page: page, quality: quality, minimumRating: minimumRating,
            queryTerm: queryTerm, genre: genre, sortBy: sortBy, orderBy: orderBy,
            withRTRatings: withRTRatings
        )
        
        #if DEBUG
        print("🔍 Checking cache for key: '\(cacheKey)'")
        print("   - Cache has \(movieListCache.count) entries")
        if let cached = movieListCache[cacheKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("   - Found cached entry: \(cached.data.movies.count) movies, \(Int(age))s old")
        } else {
            print("   - No cached entry found")
        }
        #endif
        
        if isCacheEnabled, let cached = movieListCache[cacheKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached movie list (\(cached.data.movies.count) movies, \(Int(age))s old)")
                return cached.data
            }
        }
        
        // Fetch from network
        var components = URLComponents(string: "\(baseURL)/list_movies.json")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "minimum_rating", value: String(minimumRating)),
            URLQueryItem(name: "sort_by", value: sortBy),
            URLQueryItem(name: "order_by", value: orderBy),
            URLQueryItem(name: "with_rt_ratings", value: withRTRatings ? "true" : "false")
        ]
        
        if let quality = quality {
            queryItems.append(URLQueryItem(name: "quality", value: quality))
        }
        
        if let queryTerm = queryTerm, !queryTerm.isEmpty {
            queryItems.append(URLQueryItem(name: "query_term", value: queryTerm))
        }
        
        if let genre = genre, !genre.isEmpty {
            queryItems.append(URLQueryItem(name: "genre", value: genre))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("📡 Fetching movies from: \(url)")
        
        do {
            let (data, _) = try await session.data(from: url)
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Movie list response (\(data.count) bytes): \(responseString.prefix(1000))...")
            }
            #endif
            
            let response = try JSONDecoder().decode(MovieListResponse.self, from: data)
            let allMovies = response.data.movies ?? []
            
            // Filter out invalid movies and log any that were skipped
            let validMovies = allMovies.filter { movie in
                let isValid = movie.isValid
                if !isValid {
                    print("⚠️ Skipping invalid movie (ID: \(movie.id), title: '\(movie.safeTitle)')")
                }
                return isValid
            }
            
            let skippedCount = allMovies.count - validMovies.count
            if skippedCount > 0 {
                print("📊 Filtered out \(skippedCount) invalid movies from \(allMovies.count) total")
            }

            // Create result with pagination metadata
            let result = MovieListResult(
                movies: validMovies,
                totalCount: response.data.movieCount,
                currentPage: response.data.pageNumber,
                limit: response.data.limit
            )

            // Cache the result only if caching is enabled
            if isCacheEnabled {
                movieListCache[cacheKey] = (data: result, timestamp: Date())
                print("✅ Successfully decoded \(validMovies.count) valid movies (cached)")
                #if DEBUG
                print("💾 Cached \(validMovies.count) movies with key: '\(cacheKey)'")
                print("   - Query term was: '\(queryTerm ?? "nil")'")
                #endif
            } else {
                print("✅ Successfully decoded \(validMovies.count) valid movies (no cache)")
            }
            
            return result
        } catch let error as DecodingError {
            print("❌ Movie list decoding error: \(error)")
            throw APIError.decodingError(self.enhancedDecodingError(error))
        } catch {
            print("❌ Movie list network error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Movie Details with Caching
    
    func fetchMovieDetails(movieId: Int, withImages: Bool = true, withCast: Bool = true) async throws -> MovieDetails {
        // Clean up expired cache entries
        cleanupCaches()
        
        // Check cache first
        if isCacheEnabled, let cached = movieDetailsCache[movieId] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached movie details for ID \(movieId) (\(Int(age))s old)")
                return cached.data
            }
        }
        
        // Fetch from network
        var components = URLComponents(string: "\(baseURL)/movie_details.json")!
        
        components.queryItems = [
            URLQueryItem(name: "movie_id", value: String(movieId)),
            URLQueryItem(name: "with_images", value: withImages ? "true" : "false"),
            URLQueryItem(name: "with_cast", value: withCast ? "true" : "false")
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("📡 Fetching movie details for ID \(movieId) from: \(url)")

        do {
            let (data, _) = try await session.data(from: url)
            
            // Debug: Print raw response if decoding fails
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Movie details response for \(movieId) (\(data.count) bytes): \(responseString.prefix(1500))...")
            }
            #endif
            
            let response = try JSONDecoder().decode(MovieDetailsResponse.self, from: data)
            let movieDetails = response.data.movie
            
            // Cache the result only if caching is enabled
            if isCacheEnabled {
                movieDetailsCache[movieId] = (data: movieDetails, timestamp: Date())
                print("✅ Successfully decoded movie details for: \(movieDetails.safeTitle) (cached)")
            } else {
                print("✅ Successfully decoded movie details for: \(movieDetails.safeTitle) (no cache)")
            }
            
            return movieDetails
        } catch let error as DecodingError {
            print("❌ Movie details decoding error for ID \(movieId): \(error)")
            // Enhanced error reporting
            throw APIError.decodingError(self.enhancedDecodingError(error))
        } catch {
            print("❌ Movie details network error for ID \(movieId): \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Movie Suggestions with Caching
    
    func fetchMovieSuggestions(movieId: Int) async throws -> [Movie] {
        // Clean up expired cache entries
        cleanupCaches()
        
        // Check cache first
        if isCacheEnabled, let cached = movieSuggestionsCache[movieId] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached suggestions for movie ID \(movieId) (\(cached.data.count) movies, \(Int(age))s old)")
                return cached.data
            }
        }
        
        // Fetch from network
        var components = URLComponents(string: "\(baseURL)/movie_suggestions.json")!
        
        components.queryItems = [
            URLQueryItem(name: "movie_id", value: String(movieId))
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("📡 Fetching suggestions for movie ID \(movieId) from: \(url)")

        do {
            let (data, _) = try await session.data(from: url)
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Movie suggestions response (\(data.count) bytes): \(responseString.prefix(800))...")
            }
            #endif
            
            let response = try JSONDecoder().decode(MovieSuggestionsResponse.self, from: data)
            let allSuggestions = response.data.movies ?? []
            
            // Filter out invalid movies and log any that were skipped
            let validSuggestions = allSuggestions.filter { movie in
                let isValid = movie.isValid
                if !isValid {
                    print("⚠️ Skipping invalid suggested movie (ID: \(movie.id), title: '\(movie.safeTitle)')")
                }
                return isValid
            }
            
            let skippedCount = allSuggestions.count - validSuggestions.count
            if skippedCount > 0 {
                print("📊 Filtered out \(skippedCount) invalid suggestions from \(allSuggestions.count) total")
            }

            // Cache the result only if caching is enabled
            if isCacheEnabled {
                movieSuggestionsCache[movieId] = (data: validSuggestions, timestamp: Date())
                print("✅ Successfully decoded \(validSuggestions.count) valid suggested movies (cached)")
            } else {
                print("✅ Successfully decoded \(validSuggestions.count) valid suggested movies (no cache)")
            }

            return validSuggestions
        } catch let error as DecodingError {
            print("❌ Movie suggestions decoding error: \(error)")
            throw APIError.decodingError(self.enhancedDecodingError(error))
        } catch {
            print("❌ Movie suggestions network error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    func fetchRecentMovies() async throws -> MovieListResult {
        return try await fetchMovies(
            quality: "1080p",
            withRTRatings: true
        )
    }
    
    func searchMovies(query: String, quality: String = "1080p") async throws -> MovieListResult {
        return try await fetchMovies(
            quality: quality,
            queryTerm: query
        )
    }
    
    // MARK: - Helper Methods
    
    private func enhancedDecodingError(_ error: DecodingError) -> NSError {
        switch error {
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let description = "Missing required key '\(key.stringValue)' at path: \(path.isEmpty ? "root" : path)"
            print("🔍 Missing key details: \(description)")
            return NSError(domain: "DecodingError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: description
            ])
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let description = "Type mismatch for expected type '\(type)' at path: \(path.isEmpty ? "root" : path)"
            print("🔍 Type mismatch details: \(description)")
            return NSError(domain: "DecodingError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: description
            ])
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let description = "Value not found for type '\(type)' at path: \(path.isEmpty ? "root" : path)"
            print("🔍 Value not found details: \(description)")
            return NSError(domain: "DecodingError", code: 3, userInfo: [
                NSLocalizedDescriptionKey: description
            ])
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let description = "Data corrupted at path: \(path.isEmpty ? "root" : path). Debug info: \(context.debugDescription)"
            print("🔍 Data corruption details: \(description)")
            return NSError(domain: "DecodingError", code: 4, userInfo: [
                NSLocalizedDescriptionKey: description
            ])
        @unknown default:
            return NSError(domain: "DecodingError", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Unknown decoding error: \(error)"
            ])
        }
    }
} 