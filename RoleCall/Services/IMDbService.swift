//
//  IMDbService.swift
//  RoleCall
//
//  Created by Eric on 7/30/25.
//

import Foundation

@MainActor
class IMDbService: ObservableObject {
    private let baseURL = "https://rest.imdbapi.dev/v2"
    private let session: URLSession

    // In-memory cache for responses
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour cache
    private let maxCacheSize = 50

    init() {
        // Configure URLSession for REST requests
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30

        self.session = URLSession(configuration: config)
    }

    enum IMDbError: Error, LocalizedError {
        case invalidURL
        case noData
        case invalidIMDbID
        case apiError(String)
        case decodingError(Error)
        case networkError(Error)
        case httpError(Int)
        case actorNotFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid IMDb API URL"
            case .noData:
                return "No data received from IMDb API"
            case .invalidIMDbID:
                return "Invalid or missing IMDb ID"
            case .apiError(let message):
                return "IMDb API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode IMDb data: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .actorNotFound:
                return "Actor not found in IMDb database"
            }
        }
    }

    // MARK: - Public Methods

    /// Search for a person by name (returns multiple potential matches)
    /// Note: This method now requires additional context since the IMDb search API is broken
    func searchPerson(name: String, imdbMovieID: String? = nil) async throws -> IMDbPersonSearchResponse {
        print("🔍 IMDb: Searching for person '\(name)'")
        
        // If we have a movie IMDb ID, search within that movie's cast
        if let movieID = imdbMovieID {
            print("🎬 Using movie context: \(movieID)")
            let actor = try await findActorInMovie(actorName: name, imdbMovieID: movieID)
            if let actor = actor {
                return IMDbPersonSearchResponse(results: [actor])
            }
        }
        
        // Fallback: Without working search API, we cannot find actors by name alone
        // This should be handled by getting IMDb IDs from Plex metadata
        throw IMDbError.actorNotFound
    }

    /// Get detailed information about a person by IMDb name ID (nm0000001 format)
    func getPersonDetails(nameID: String) async throws -> IMDbPersonDetails {
        print("🔍 IMDb: Getting person details for '\(nameID)'")

        // Check cache first
        let cacheKey = "person_\(nameID)"
        if let cached = cache[cacheKey] as? (data: IMDbPersonDetails, timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached person details for \(nameID)")
                return cached.data
            }
        }

        let personInfo = try await fetchPersonDetails(nameID: nameID)

        // Cache the result
        cache[cacheKey] = (data: personInfo, timestamp: Date())
        cleanupCache()

        return personInfo
    }

    /// Get movie credits for a person by IMDb name ID
    func getPersonMovieCredits(nameID: String) async throws -> IMDbPersonMovieCredits {
        print("🔍 IMDb: Getting movie credits for '\(nameID)'")

        // Check cache first
        let cacheKey = "credits_\(nameID)"
        if let cached = cache[cacheKey] as? (data: IMDbPersonMovieCredits, timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached movie credits for \(nameID)")
                return cached.data
            }
        }

        let knownForResponse = try await fetchPersonKnownFor(nameID: nameID)
        let movieCredits = convertToMovieCredits(knownForResponse)

        // Cache the result
        cache[cacheKey] = (data: movieCredits, timestamp: Date())
        cleanupCache()

        return movieCredits
    }

    /// Get detailed information about a movie by IMDb title ID (tt0000001 format)
    func getMovieDetails(titleID: String) async throws -> IMDbMovieDetails {
        print("🔍 IMDb: Getting movie details for '\(titleID)'")

        // Check cache first
        let cacheKey = "movie_\(titleID)"
        if let cached = cache[cacheKey] as? (data: IMDbMovieDetails, timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached movie details for \(titleID)")
                return cached.data
            }
        }

        let movieDetails = try await fetchMovieDetails(titleID: titleID)

        // Cache the result
        cache[cacheKey] = (data: movieDetails, timestamp: Date())
        cleanupCache()

        return movieDetails
    }

    /// Search for a movie by title (for future use)
    func searchMovie(title: String, year: Int? = nil) async throws -> IMDbMovieSearchResponse {
        print("🔍 IMDb: Searching for movie '\(title)'")

        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/titles?q=\(encodedTitle)&page_size=10") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(TitleSearchResponse.self, from: data)
        return IMDbMovieSearchResponse(results: searchResponse.results.map { title in
            IMDbMovieSearchResult(
                id: title.id,
                title: title.primaryTitle,
                releaseDate: title.startYear != nil ? "\(title.startYear!)" : nil,
                overview: title.plot,
                posterPath: title.primaryImage?.url,
                voteAverage: title.rating?.aggregateRating ?? 0.0,
                popularity: 0.0 // Not available in IMDb API
            )
        })
    }

    /// Generate full URL for profile image
    func profileImageURL(path: String?, size: IMDbImageSize = .w500) -> URL? {
        guard let path = path else { return nil }
        return URL(string: path) // IMDb provides full URLs
    }

    /// Generate full URL for poster image
    func posterImageURL(path: String?, size: IMDbImageSize = .w342) -> URL? {
        guard let path = path else { return nil }
        return URL(string: path) // IMDb provides full URLs
    }

    // MARK: - Private Methods

    /// Find an actor by name within a specific movie's cast
    private func findActorInMovie(actorName: String, imdbMovieID: String) async throws -> IMDbPersonSearchResult? {
        let credits = try await fetchCredits(imdbID: imdbMovieID)
        
        // Find the actor in the movie's cast
        let matchingActor = credits.credits.first { credit in
            (credit.category == "ACTOR" || credit.category == "ACTRESS") &&
            (credit.name.displayName.lowercased().contains(actorName.lowercased()) ||
             actorName.lowercased().contains(credit.name.displayName.lowercased()))
        }
        
        guard let actor = matchingActor else {
            return nil
        }
        
        return IMDbPersonSearchResult(
            id: actor.name.id,
            name: actor.name.displayName,
            profilePath: actor.name.primaryImage?.url,
            knownForDepartment: actor.category == "ACTRESS" ? "Acting" : "Acting",
            popularity: 0.0, // Not available
            knownFor: [] // Will be populated by getPersonMovieCredits
        )
    }

    private func fetchPersonDetails(nameID: String) async throws -> IMDbPersonDetails {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        let personInfo = try JSONDecoder().decode(RestPersonInfo.self, from: data)

        return IMDbPersonDetails(
            id: personInfo.id,
            name: personInfo.displayName,
            biography: personInfo.biography,
            birthday: formatDate(personInfo.birthDate),
            deathday: formatDate(personInfo.deathDate),
            placeOfBirth: personInfo.birthLocation,
            profilePath: personInfo.primaryImage?.url,
            knownForDepartment: personInfo.primaryProfessions?.first,
            popularity: 0.0 // Not available in IMDb API
        )
    }

    private func fetchPersonKnownFor(nameID: String) async throws -> RestKnownForResponse {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/known_for?page_size=20") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(RestKnownForResponse.self, from: data)
    }

    private func fetchCredits(imdbID: String) async throws -> RestCreditsResponse {
        guard let url = URL(string: "\(baseURL)/titles/\(imdbID)/credits?page_size=50") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(RestCreditsResponse.self, from: data)
    }

    private func convertToMovieCredits(_ knownForResponse: RestKnownForResponse) -> IMDbPersonMovieCredits {
        let movieCredits = knownForResponse.knownFor.compactMap { credit -> IMDbMovieCredit? in
            guard let title = credit.title else { return nil }

            return IMDbMovieCredit(
                id: title.id,
                title: title.primaryTitle,
                character: credit.characters?.first,
                job: credit.category,
                releaseDate: title.startYear != nil ? "\(title.startYear!)" : nil,
                posterPath: title.primaryImage?.url,
                voteAverage: title.rating?.aggregateRating ?? 0.0,
                popularity: 0.0 // Not available
            )
        }

        return IMDbPersonMovieCredits(
            cast: movieCredits,
            crew: [] // We'll use cast for everything for simplicity
        )
    }

    private func formatDate(_ restDate: RestBirthDate?) -> String? {
        guard let restDate = restDate,
              let year = restDate.year else { return nil }

        if let month = restDate.month, let day = restDate.day {
            return String(format: "%04d-%02d-%02d", year, month, day)
        } else {
            return "\(year)"
        }
    }

    private func cleanupCache() {
        if cache.count > maxCacheSize {
            // Remove oldest entries based on timestamp in the tuple value
            let sortedEntries = cache.sorted { first, second in
                first.value.timestamp < second.value.timestamp
            }
            // Keep only the most recent entries
            cache = Dictionary(uniqueKeysWithValues: Array(sortedEntries.suffix(maxCacheSize)))
        }
    }

    /// Fetch detailed movie information from IMDb API
    private func fetchMovieDetails(titleID: String) async throws -> IMDbMovieDetails {
        guard titleID.hasPrefix("tt") else {
            throw IMDbError.invalidIMDbID
        }

        guard let url = URL(string: "\(baseURL)/titles/\(titleID)") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    throw IMDbError.httpError(httpResponse.statusCode)
                }
            }

            // Parse the response - note that the IMDb API might return a different structure
            // We'll need to map it to our IMDbMovieDetails model
            let apiResponse = try JSONDecoder().decode(IMDbTitleDetailResponse.self, from: data)
            
            // Debug logging
            print("🔍 DEBUG: API Response for \(titleID):")
            print("   primaryTitle: '\(apiResponse.primaryTitle ?? "nil")'")
            print("   originalTitle: '\(apiResponse.originalTitle ?? "nil")'")
            print("   rating: \(apiResponse.rating?.aggregateRating ?? 0.0)")
            print("   plot: '\(apiResponse.plot?.prefix(50) ?? "nil")...'")
            
            return IMDbMovieDetails(
                id: apiResponse.id,
                title: apiResponse.primaryTitle ?? apiResponse.originalTitle ?? "Unknown Title",
                originalTitle: apiResponse.originalTitle,
                releaseDate: apiResponse.startYear != nil ? "\(apiResponse.startYear!)" : nil,
                runtime: apiResponse.runtimeMinutes,
                overview: apiResponse.plot,
                tagline: nil, // Not available in this API
                posterPath: apiResponse.primaryImage?.url,
                backdropPath: nil, // Not available in this API
                voteAverage: apiResponse.rating?.aggregateRating ?? 0.0,
                voteCount: apiResponse.rating?.numVotes ?? 0,
                popularity: 0.0, // Not available in this API
                genres: apiResponse.genres?.enumerated().map { IMDbGenre(id: $0.offset + 1, name: $0.element) },
                productionCountries: nil, // Not available in this API
                spokenLanguages: nil, // Not available in this API
                productionCompanies: nil, // Not available in this API
                budget: nil, // Not available in this API
                revenue: nil, // Not available in this API
                status: nil, // Not available in this API
                adult: apiResponse.isAdult ?? false
            )

        } catch let decodingError as DecodingError {
            print("❌ Failed to decode movie details: \(decodingError)")
            throw IMDbError.decodingError(decodingError)
        } catch {
            print("❌ Network error fetching movie details: \(error)")
            throw IMDbError.networkError(error)
        }
    }
}

// MARK: - IMDb Image Sizes
enum IMDbImageSize: String {
    case w92 = "w92"
    case w154 = "w154"
    case w185 = "w185"
    case w342 = "w342"
    case w500 = "w500"
    case w780 = "w780"
    case original = "original"
}
