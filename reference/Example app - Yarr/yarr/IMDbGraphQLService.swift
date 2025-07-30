//
//  IMDbGraphQLService.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation

@MainActor
class IMDbGraphQLService: ObservableObject {
    private let baseURL = "https://graph.imdbapi.dev/v1"
    private let session: URLSession
    
    // In-memory cache for IMDb responses
    private var imdbCache: [String: (data: IMDbTitleInfo, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour cache
    private let maxCacheSize = 50
    
    init() {
        // Configure URLSession for GraphQL requests
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        
        self.session = URLSession(configuration: config)
    }
    
    enum GraphQLError: Error, LocalizedError {
        case invalidURL
        case noData
        case invalidIMDbID
        case graphQLError(String)
        case persistedQueryNotFound
        case decodingError(Error)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid GraphQL URL"
            case .noData:
                return "No data received from IMDb API"
            case .invalidIMDbID:
                return "Invalid or missing IMDb ID"
            case .graphQLError(let message):
                return "IMDb API error: \(message)"
            case .persistedQueryNotFound:
                return "IMDb API query format error - trying fallback method"
            case .decodingError(let error):
                return "Failed to decode IMDb data: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    // Test method for debugging API connection
    func testConnection() async throws -> Bool {
        let testQuery = "{ __schema { types { name } } }"
        
        guard let url = URL(string: baseURL) else {
            throw GraphQLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        
        let requestBody = GraphQLRequest(query: testQuery, operationName: nil, variables: [:])
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🧪 Test connection status: \(httpResponse.statusCode)")
            return httpResponse.statusCode == 200
        }
        
        return false
    }
    
    func fetchMoviePlot(imdbID: String) async throws -> IMDbTitleInfo {
        // Validate IMDb ID format
        let cleanID = cleanIMDbID(imdbID)
        guard isValidIMDbID(cleanID) else {
            throw GraphQLError.invalidIMDbID
        }
        
        // Check cache first
        if let cached = imdbCache[cleanID] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached IMDb data for \(cleanID) (\(Int(age))s old)")
                return cached.data
            }
        }
        
        // Clean up cache periodically
        cleanupCache()
        
        // Try primary method first, fallback if PersistedQueryNotFound
        do {
            return try await performGraphQLRequest(imdbID: cleanID, useCompactQuery: false)
        } catch GraphQLError.persistedQueryNotFound {
            print("🔄 Retrying with compact query format...")
            return try await performGraphQLRequest(imdbID: cleanID, useCompactQuery: true)
        }
    }
    
    private func performGraphQLRequest(imdbID: String, useCompactQuery: Bool) async throws -> IMDbTitleInfo {
        
        // Prepare GraphQL query - use compact version if needed
        let query: String
        
        if useCompactQuery {
            // Simplified query for fallback
            query = """
            {
              title(id: "\(imdbID)") {
                id
                type
                start_year
                plot
                genres
                rating {
                  aggregate_rating
                  votes_count
                }
                critic_review {
                  score
                  review_count
                }
                spoken_languages {
                  code
                  name
                }
                origin_countries {
                  code
                  name
                }
                directors: credits(first: 3, categories:["director"]) {
                  name {
                    id
                    display_name
                    birth_year
                    avatars {
                      url
                      width
                      height
                    }
                  }
                }
                writers: credits(first: 3, categories:["writer"]) {
                  name {
                    id
                    display_name
                    birth_year
                    avatars {
                      url
                      width
                      height
                    }
                  }
                }
                casts: credits(first: 6, categories:["actor","actress"]) {
                  name {
                    id
                    display_name
                    birth_year
                    avatars {
                      url
                      width
                      height
                    }
                  }
                  characters
                }
              }
            }
            """
        } else {
            // Full query with enhanced cast, directors, and writers
            query = """
            {
              title(id: "\(imdbID)") {
                id
                type
                start_year
                plot
                genres
                rating {
                  aggregate_rating
                  votes_count
                }
                critic_review {
                  score
                  review_count
                }
                spoken_languages {
                  code
                  name
                }
                origin_countries {
                  code
                  name
                }
                directors: credits(first: 5, categories:[ "director" ]) {
                  name {
                    id
                    display_name
                    birth_year
                    birth_location
                    death_year
                    death_location
                    dead_reason
                    known_for {
                      id
                      primary_title
                      start_year
                      rating {
                        aggregate_rating
                        votes_count
                      }
                    }
                    avatars {
                      url
                      width
                      height
                    }
                  }
                }
                writers: credits(first: 5, categories:[ "writer" ]) {
                  name {
                    id
                    display_name
                    birth_year
                    birth_location
                    death_year
                    death_location
                    dead_reason
                    known_for {
                      id
                      primary_title
                      start_year
                      rating {
                        aggregate_rating
                        votes_count
                      }
                    }
                    avatars {
                      url
                      width
                      height
                    }
                  }
                }
                casts: credits(first: 8, categories:[ "actor", "actress" ]) {
                  name {
                    id
                    display_name
                    birth_year
                    birth_location
                    death_year
                    death_location
                    dead_reason
                    known_for {
                      id
                      primary_title
                      start_year
                      rating {
                        aggregate_rating
                        votes_count
                      }
                    }
                    avatars {
                      url
                      width
                      height
                    }
                  }
                  characters
                }
              }
            }
            """
        }
        
        guard let url = URL(string: baseURL) else {
            throw GraphQLError.invalidURL
        }
        
        // Create GraphQL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        
        let requestBody = GraphQLRequest(query: query, operationName: nil, variables: [:])
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            throw GraphQLError.decodingError(error)
        }
        
        print("📡 Fetching IMDb data for \(imdbID) from GraphQL API \(useCompactQuery ? "(compact)" : "(full)")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 IMDb API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw GraphQLError.networkError(URLError(.badServerResponse))
                }
            }
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 IMDb GraphQL response (\(data.count) bytes): \(responseString.prefix(500))...")
                // Log first line to quickly see if it contains error
                if let firstLine = responseString.components(separatedBy: .newlines).first {
                    print("📥 First line: \(firstLine)")
                }
            }
            #endif
            
            let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)
            
            // Check for GraphQL errors
            if let errors = graphQLResponse.errors, !errors.isEmpty {
                let errorMessage = errors.map { $0.message }.joined(separator: ", ")
                
                // Handle specific error types
                if errorMessage.contains("PersistedQueryNotFound") {
                    print("⚠️ PersistedQueryNotFound error detected - this might be due to request format")
                    throw GraphQLError.persistedQueryNotFound
                }
                
                throw GraphQLError.graphQLError(errorMessage)
            }
            
            guard let titleData = graphQLResponse.data?.title else {
                throw GraphQLError.noData
            }
            
            // Cache the result
            imdbCache[imdbID] = (data: titleData, timestamp: Date())
            
            print("✅ Successfully fetched IMDb data for \(titleData.id)")
            return titleData
            
        } catch let error as GraphQLError {
            throw error
        } catch let error as DecodingError {
            print("❌ IMDb decoding error: \(error)")
            throw GraphQLError.decodingError(error)
        } catch {
            print("❌ IMDb network error: \(error)")
            throw GraphQLError.networkError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func cleanIMDbID(_ id: String) -> String {
        // Remove any whitespace and ensure it starts with "tt"
        let cleanID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanID.hasPrefix("tt") ? cleanID : "tt\(cleanID)"
    }
    
    private func isValidIMDbID(_ id: String) -> Bool {
        // IMDb IDs should be in format "tt" followed by 7-8 digits
        let pattern = "^tt\\d{7,8}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: id)
    }
    
    private func cleanupCache() {
        let now = Date()
        
        // Remove expired entries
        imdbCache = imdbCache.filter { 
            now.timeIntervalSince($0.value.timestamp) < cacheTimeout 
        }
        
        // Limit cache size
        if imdbCache.count > maxCacheSize {
            let sortedKeys = imdbCache.keys.sorted { 
                imdbCache[$0]!.timestamp > imdbCache[$1]!.timestamp 
            }
            let keysToRemove = Array(sortedKeys.dropFirst(maxCacheSize))
            keysToRemove.forEach { imdbCache.removeValue(forKey: $0) }
        }
    }
}

// MARK: - GraphQL Models

struct GraphQLRequest: Codable {
    let query: String
    let operationName: String?
    let variables: [String: String]
}

struct GraphQLResponse: Codable {
    let data: GraphQLData?
    let errors: [GraphQLError]?
    
    struct GraphQLError: Codable {
        let message: String
    }
}

struct GraphQLData: Codable {
    let title: IMDbTitleInfo?
}

struct IMDbTitleInfo: Codable {
    let id: String
    let type: String?
    let startYear: Int?
    let plot: String?
    let genres: [String]?
    let rating: IMDbRating?
    let criticReview: IMDbCriticReview?
    let spokenLanguages: [IMDbLanguage]?
    let originCountries: [IMDbCountry]?
    let directors: [IMDbCredit]?
    let writers: [IMDbCredit]?
    let casts: [IMDbCastCredit]?
    
    enum CodingKeys: String, CodingKey {
        case id, type, plot, genres, rating, directors, writers, casts
        case startYear = "start_year"
        case criticReview = "critic_review"
        case spokenLanguages = "spoken_languages"
        case originCountries = "origin_countries"
    }
}

struct IMDbRating: Codable {
    let aggregateRating: Double?
    let votesCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case aggregateRating = "aggregate_rating"
        case votesCount = "votes_count"
    }
}

struct IMDbCriticReview: Codable {
    let score: Int?
    let reviewCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case score
        case reviewCount = "review_count"
    }
}

struct IMDbCredit: Codable, Identifiable {
    let id = UUID()
    let name: IMDbPerson
    
    private enum CodingKeys: String, CodingKey {
        case name
    }
}

struct IMDbCastCredit: Codable, Identifiable {
    let id = UUID()
    let name: IMDbPerson
    let characters: [String]?
    
    var characterString: String {
        return characters?.joined(separator: ", ") ?? "Unknown Character"
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, characters
    }
}

struct IMDbPerson: Codable {
    let id: String
    let displayName: String
    let birthYear: Int?
    let birthLocation: String?
    let deathYear: Int?
    let deathLocation: String?
    let deadReason: String?
    let knownFor: [IMDbTitle]?
    let avatars: [IMDbAvatar]?
    
    var bestAvatar: IMDbAvatar? {
        // Return the largest available avatar
        return avatars?.max { $0.width < $1.width }
    }
    
    // Check if the person is deceased
    var isDeceased: Bool {
        return deathYear != nil
    }
    
    // Calculate age at the time of movie production
    func ageAtMovieProduction(movieYear: Int) -> Int? {
        guard let birthYear = birthYear else { return nil }
        return movieYear - birthYear
    }
    
    // Calculate current age (or age at death for deceased persons)
    var currentAge: Int? {
        guard let birthYear = birthYear else { return nil }
        
        if let deathYear = deathYear {
            // Person is deceased, return age at death
            return deathYear - birthYear
        } else {
            // Person is alive, return current age
            let currentYear = Calendar.current.component(.year, from: Date())
            return currentYear - birthYear
        }
    }
    
    // Format death information for display
    var deathInfo: String? {
        guard isDeceased else { return nil }
        
        var deathParts: [String] = []
        
        if let deathYear = deathYear {
            deathParts.append(String(deathYear))
        }
        
        if let deathLocation = deathLocation, !deathLocation.isEmpty {
            deathParts.append(deathLocation)
        }
        
        // Handle the cause of death separately to avoid trailing comma
        let baseInfo = deathParts.joined(separator: ", ")
        
        if let deadReason = deadReason, !deadReason.isEmpty {
            return baseInfo.isEmpty ? "(\(deadReason))" : "\(baseInfo) (\(deadReason))"
        }
        
        return baseInfo.isEmpty ? nil : baseInfo
    }
    
    // Format birth information for display
    var birthInfo: String? {
        var birthParts: [String] = []
        
        if let birthYear = birthYear {
            birthParts.append(String(birthYear))
        }
        
        if let birthLocation = birthLocation, !birthLocation.isEmpty {
            birthParts.append(birthLocation)
        }
        
        return birthParts.isEmpty ? nil : birthParts.joined(separator: ", ")
    }
    
    // Format known for list for display
    var knownForDisplay: String? {
        guard let knownFor = knownFor, !knownFor.isEmpty else { return nil }
        
        // Remove duplicates based on primary title (case-insensitive)
        var uniqueTitles: [IMDbTitle] = []
        var seenTitles: Set<String> = []
        
        for title in knownFor {
            if let primaryTitle = title.primaryTitle?.lowercased(), !seenTitles.contains(primaryTitle) {
                seenTitles.insert(primaryTitle)
                uniqueTitles.append(title)
            }
        }
        
        // Sort by rating (highest first), then by title name if no rating
        let sortedTitles = uniqueTitles.sorted { title1, title2 in
            let rating1 = title1.rating?.aggregateRating ?? 0.0
            let rating2 = title2.rating?.aggregateRating ?? 0.0
            
            if rating1 != rating2 {
                return rating1 > rating2
            }
            
            // If ratings are equal (or both nil), sort alphabetically by title
            let name1 = title1.primaryTitle ?? "Unknown"
            let name2 = title2.primaryTitle ?? "Unknown"
            return name1 < name2
        }
        
        // Take top 3 and format for display
        let limitedList = Array(sortedTitles.prefix(3))
        let titleStrings = limitedList.map { title in
            return title.primaryTitle ?? "Unknown"
        }
        return titleStrings.joined(separator: ", ")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, avatars
        case displayName = "display_name"
        case birthYear = "birth_year"
        case birthLocation = "birth_location"
        case deathYear = "death_year"
        case deathLocation = "death_location"
        case deadReason = "dead_reason"
        case knownFor = "known_for"
    }
}

struct IMDbTitle: Codable {
    let id: String
    let primaryTitle: String?
    let startYear: Int?
    let rating: IMDbRating?
    
    enum CodingKeys: String, CodingKey {
        case id, rating
        case primaryTitle = "primary_title"
        case startYear = "start_year"
    }
}

struct IMDbAvatar: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct IMDbLanguage: Codable {
    let code: String
    let name: String
}

struct IMDbCountry: Codable {
    let code: String
    let name: String
} 