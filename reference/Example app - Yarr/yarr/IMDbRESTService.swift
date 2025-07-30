//
//  IMDbRESTService.swift
//  Yarr
//
//  Created by Eric on 12/30/24.
//

import Foundation

@MainActor
class IMDbRESTService: ObservableObject {
    private let baseURL = "https://rest.imdbapi.dev/v2"
    private let session: URLSession
    
    // In-memory cache for IMDb responses
    private var imdbCache: [String: (data: IMDbTitleInfo, timestamp: Date)] = [:]
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
    
    enum RESTError: Error, LocalizedError {
        case invalidURL
        case noData
        case invalidIMDbID
        case apiError(String)
        case decodingError(Error)
        case networkError(Error)
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid REST API URL"
            case .noData:
                return "No data received from IMDb REST API"
            case .invalidIMDbID:
                return "Invalid or missing IMDb ID"
            case .apiError(let message):
                return "IMDb REST API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode IMDb data: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpError(let code):
                return "HTTP error: \(code)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    // Test method for debugging API connection
    func testConnection() async throws -> Bool {
        // Test with a well-known movie ID
        let testID = "tt0111161" // The Shawshank Redemption
        
        guard let url = URL(string: "\(baseURL)/titles/\(testID)") else {
            throw RESTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🧪 Test connection status: \(httpResponse.statusCode)")
            return httpResponse.statusCode == 200
        }
        
        return false
    }
    
    // Test method for debugging name API
    func testNameAPI() async throws {
        // Test with Ryan Reynolds
        let ryanReynoldsID = "nm0005351"
        
        do {
            let personInfo = try await fetchPersonDetails(nameID: ryanReynoldsID)
            print("🧪 Ryan Reynolds test result:")
            print("   Birth year: \(personInfo.birthDate?.year ?? 0)")
            print("   Birth location: \(personInfo.birthLocation ?? "none")")
            print("   Biography length: \(personInfo.biography?.count ?? 0) chars")
        } catch {
            print("🧪 Ryan Reynolds test failed: \(error)")
        }
    }
    
    func fetchMoviePlot(imdbID: String) async throws -> IMDbTitleInfo {
        // Validate IMDb ID format
        let cleanID = cleanIMDbID(imdbID)
        guard isValidIMDbID(cleanID) else {
            throw RESTError.invalidIMDbID
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
        
        // Fetch title info and credits concurrently
        async let titleInfo = fetchTitleInfo(imdbID: cleanID)
        async let credits = fetchCredits(imdbID: cleanID)
        
        do {
            let (title, creditsList) = try await (titleInfo, credits)
            
            // Convert REST API response to IMDbTitleInfo format with enhanced person data
            let imdbInfo = await convertToIMDbTitleInfo(title: title, credits: creditsList)
            
            // Cache the result
            imdbCache[cleanID] = (data: imdbInfo, timestamp: Date())
            
            print("✅ Successfully fetched IMDb data for \(imdbInfo.id)")
            return imdbInfo
            
        } catch {
            print("❌ Failed to fetch IMDb data for \(cleanID): \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchTitleInfo(imdbID: String) async throws -> RESTTitleInfo {
        guard let url = URL(string: "\(baseURL)/titles/\(imdbID)") else {
            throw RESTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        
        print("📡 Fetching title info for \(imdbID) from REST API")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Title info API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw RESTError.httpError(httpResponse.statusCode)
                }
            }
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Title info response (\(data.count) bytes): \(responseString.prefix(500))...")
            }
            #endif
            
            let titleInfo = try JSONDecoder().decode(RESTTitleInfo.self, from: data)
            return titleInfo
            
        } catch let error as DecodingError {
            print("❌ Title info decoding error: \(error)")
            throw RESTError.decodingError(error)
        } catch let error as RESTError {
            throw error
        } catch {
            print("❌ Title info network error: \(error)")
            throw RESTError.networkError(error)
        }
    }
    
    private func fetchCredits(imdbID: String) async throws -> RESTCreditsResponse {
        // Fetch all credits with pagination support
        return try await fetchAllCredits(imdbID: imdbID)
    }
    
    private func fetchAllCredits(imdbID: String, pageToken: String? = nil) async throws -> RESTCreditsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/titles/\(imdbID)/credits")!
        
        // Set page size to maximum to reduce API calls
        urlComponents.queryItems = [
            URLQueryItem(name: "page_size", value: "50")
        ]
        
        // Add page token if provided
        if let pageToken = pageToken {
            urlComponents.queryItems?.append(URLQueryItem(name: "page_token", value: pageToken))
        }
        
        guard let url = urlComponents.url else {
            throw RESTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        
        print("📡 Fetching credits for \(imdbID) from REST API (page_size: 50)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Credits API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw RESTError.httpError(httpResponse.statusCode)
                }
            }
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Credits response (\(data.count) bytes): \(responseString.prefix(500))...")
            }
            #endif
            
            var creditsResponse = try JSONDecoder().decode(RESTCreditsResponse.self, from: data)
            
            // If there's a next page token, fetch the next page and combine results
            if let nextPageToken = creditsResponse.nextPageToken, !nextPageToken.isEmpty {
                print("📡 Fetching next page of credits...")
                let nextPageResponse = try await fetchAllCredits(imdbID: imdbID, pageToken: nextPageToken)
                creditsResponse.credits.append(contentsOf: nextPageResponse.credits)
            }
            
            print("📡 Total credits fetched: \(creditsResponse.credits.count)")
            return creditsResponse
            
        } catch let error as DecodingError {
            print("❌ Credits decoding error: \(error)")
            throw RESTError.decodingError(error)
        } catch let error as RESTError {
            throw error
        } catch {
            print("❌ Credits network error: \(error)")
            throw RESTError.networkError(error)
        }
    }
    
    private func fetchPersonDetails(nameID: String) async throws -> RESTPersonInfo {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)") else {
            throw RESTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        
        print("📡 Fetching person details for \(nameID) from REST API")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Person details API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw RESTError.httpError(httpResponse.statusCode)
                }
            }
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Person details response (\(data.count) bytes): \(responseString.prefix(500))...")
            }
            #endif
            
            let personInfo = try JSONDecoder().decode(RESTPersonInfo.self, from: data)
            return personInfo
            
        } catch let error as DecodingError {
            print("❌ Person details decoding error: \(error)")
            throw RESTError.decodingError(error)
        } catch let error as RESTError {
            throw error
        } catch {
            print("❌ Person details network error: \(error)")
            throw RESTError.networkError(error)
        }
    }
    
    private func fetchPersonKnownFor(nameID: String) async throws -> RESTKnownForResponse {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/known_for?page_size=6") else {
            throw RESTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Yarr/1.0", forHTTPHeaderField: "User-Agent")
        
        print("📡 Fetching known for data for \(nameID) from REST API")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Known for API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw RESTError.httpError(httpResponse.statusCode)
                }
            }
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Known for response (\(data.count) bytes): \(responseString.prefix(500))...")
            }
            #endif
            
            let knownForResponse = try JSONDecoder().decode(RESTKnownForResponse.self, from: data)
            return knownForResponse
            
        } catch let error as DecodingError {
            print("❌ Known for decoding error: \(error)")
            throw RESTError.decodingError(error)
        } catch let error as RESTError {
            throw error
        } catch {
            print("❌ Known for network error: \(error)")
            throw RESTError.networkError(error)
        }
    }
    
    private func convertToIMDbTitleInfo(title: RESTTitleInfo, credits: RESTCreditsResponse) async -> IMDbTitleInfo {
        // Convert REST API response to existing IMDbTitleInfo format
        // Always fetch enhanced biographical data since credits response is often incomplete
        
        // Get person IDs for comprehensive data with limits
        let directorCredits = credits.credits.filter { $0.category == "DIRECTOR" }
        let writerCredits = Array(credits.credits.filter { $0.category == "WRITER" }.prefix(4))
        let castCredits = Array(credits.credits.filter { $0.category == "ACTOR" || $0.category == "ACTRESS" }.prefix(12))
        
        print("🔍 Fetching enhanced biographical data for key personnel...")
        print("📊 Will fetch: \(directorCredits.count) directors, \(writerCredits.count) writers, \(castCredits.count) cast")
        
        // Fetch detailed info for more personnel now that rate limiting is fixed
        let keyDirectors = Array(directorCredits.prefix(3))
        let keyWriters = Array(writerCredits.prefix(4))  
        let keyCast = Array(castCredits.prefix(12)) // Fetch all cast members
        
        print("📊 Actually fetching: \(keyDirectors.count) directors, \(keyWriters.count) writers, \(keyCast.count) cast")
        
        async let directorDetails = fetchPersonDetailsForCredits(keyDirectors)
        async let writerDetails = fetchPersonDetailsForCredits(keyWriters)
        async let castDetails = fetchPersonDetailsForCredits(keyCast)
        
        let (directors, writers, actors) = await (directorDetails, writerDetails, castDetails)
        
        // Create lookup dictionary for enhanced data
        var enhancedData: [String: (RESTPersonInfo?, RESTKnownForResponse?)] = [:]
        for (credit, personInfo, knownFor) in directors + writers + actors {
            enhancedData[credit.name.id] = (personInfo, knownFor)
        }
        
        // Convert directors - use enhanced data when available, otherwise basic data
        let directorCreditsArray = directorCredits.map { credit in
            if let (personInfo, knownFor) = enhancedData[credit.name.id] {
                return IMDbCredit(name: convertToPerson(credit: credit, personInfo: personInfo, knownFor: knownFor))
            } else {
                return IMDbCredit(name: convertToBasicPerson(credit: credit))
            }
        }
        
        // Convert writers - use enhanced data when available, otherwise basic data
        let writerCreditsArray = writerCredits.map { credit in
            if let (personInfo, knownFor) = enhancedData[credit.name.id] {
                return IMDbCredit(name: convertToPerson(credit: credit, personInfo: personInfo, knownFor: knownFor))
            } else {
                return IMDbCredit(name: convertToBasicPerson(credit: credit))
            }
        }
        
        // Convert cast - use enhanced data when available, otherwise basic data
        let castCreditsArray = castCredits.map { credit in
            if let (personInfo, knownFor) = enhancedData[credit.name.id] {
                return IMDbCastCredit(
                    name: convertToPerson(credit: credit, personInfo: personInfo, knownFor: knownFor),
                    characters: credit.characters
                )
            } else {
                return IMDbCastCredit(
                    name: convertToBasicPerson(credit: credit),
                    characters: credit.characters
                )
            }
        }
        
        print("✅ Enhanced data fetched: \(directorCreditsArray.count) directors, \(writerCreditsArray.count) writers, \(castCreditsArray.count) cast members")
        
        return IMDbTitleInfo(
            id: title.id,
            type: title.type,
            startYear: title.startYear,
            plot: title.plot,
            genres: title.genres,
            rating: title.rating != nil ? IMDbRating(
                aggregateRating: title.rating!.aggregateRating,
                votesCount: title.rating!.votesCount
            ) : nil,
            criticReview: nil, // Not available in REST API
            spokenLanguages: nil, // Not available in REST API
            originCountries: nil, // Not available in REST API
            directors: directorCreditsArray.isEmpty ? nil : directorCreditsArray,
            writers: writerCreditsArray.isEmpty ? nil : writerCreditsArray,
            casts: castCreditsArray.isEmpty ? nil : castCreditsArray
        )
    }
    
    private func fetchPersonDetailsForCredits(_ credits: [RESTCredit]) async -> [(RESTCredit, RESTPersonInfo?, RESTKnownForResponse?)] {
        // Fetch person details sequentially to avoid rate limiting
        var results: [(RESTCredit, RESTPersonInfo?, RESTKnownForResponse?)] = []
        
        for (index, credit) in credits.enumerated() {
            print("🔍 Fetching details for: \(credit.name.displayName) (ID: \(credit.name.id)) [\(index + 1)/\(credits.count)]")
            
            do {
                // Fetch person details only (skip known_for to reduce API calls)
                let personInfo = try await fetchPersonDetails(nameID: credit.name.id)
                
                print("✅ Successfully fetched person data for \(credit.name.displayName)")
                results.append((credit, personInfo, nil))
                
                // Add delay between requests to avoid rate limiting (except for last request)
                if index < credits.count - 1 {
                    do {
                        try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    } catch {
                        // Ignore sleep errors
                    }
                }
                
            } catch {
                print("❌ Failed to fetch details for \(credit.name.displayName) (ID: \(credit.name.id)): \(error)")
                results.append((credit, nil, nil))
                
                // Add delay even for failed requests to avoid hitting rate limits harder
                if index < credits.count - 1 {
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay after failure
                    } catch {
                        // Ignore sleep errors
                    }
                }
            }
        }
        
        return results
    }
    
    private func convertToPersonFromCredit(credit: RESTCredit) -> IMDbPerson {
        // Use the rich biographical data already available in the credit's name field
        let hasBiographicalData = credit.name.birthDate != nil || credit.name.deathDate != nil || credit.name.birthLocation != nil
        
        if hasBiographicalData {
            print("✅ Found biographical data for \(credit.name.displayName): birth=\(credit.name.birthDate?.year ?? 0), death=\(credit.name.deathDate?.year ?? 0)")
        } else {
            print("⚠️ No biographical data for \(credit.name.displayName)")
        }
        
        return IMDbPerson(
            id: credit.name.id,
            displayName: credit.name.displayName,
            birthYear: credit.name.birthDate?.year,
            birthLocation: credit.name.birthLocation,
            deathYear: credit.name.deathDate?.year,
            deathLocation: credit.name.deathLocation,
            deadReason: credit.name.deathReason,
            knownFor: nil, // Skip known for data to avoid additional API calls
            avatars: credit.name.primaryImage != nil ? [IMDbAvatar(
                url: credit.name.primaryImage!.url,
                width: credit.name.primaryImage!.width,
                height: credit.name.primaryImage!.height
            )] : nil
        )
    }
    
    private func convertToPersonWithEnhancedData(credit: RESTCredit, enhancedData: [String: (RESTPersonInfo?, RESTKnownForResponse?)]) -> IMDbPerson {
        // Use enhanced data from separate API calls if available, otherwise fall back to credits data
        let (personInfo, knownFor) = enhancedData[credit.name.id] ?? (nil, nil)
        
        // Prioritize enhanced data, but fall back to credits data
        let birthYear = personInfo?.birthDate?.year ?? credit.name.birthDate?.year
        let birthLocation = personInfo?.birthLocation ?? credit.name.birthLocation
        let deathYear = personInfo?.deathDate?.year ?? credit.name.deathDate?.year
        let deathLocation = personInfo?.deathLocation ?? credit.name.deathLocation
        let deadReason = personInfo?.deathReason ?? credit.name.deathReason
        
        // Convert known for data to IMDbTitle format
        let knownForTitles: [IMDbTitle]? = knownFor?.knownFor.compactMap { (knownForCredit: RESTKnownForCredit) -> IMDbTitle? in
            guard let title = knownForCredit.title else { return nil }
            return IMDbTitle(
                id: title.id,
                primaryTitle: title.primaryTitle,
                startYear: title.startYear,
                rating: title.rating != nil ? IMDbRating(
                    aggregateRating: title.rating!.aggregateRating,
                    votesCount: title.rating!.votesCount
                ) : nil
            )
        }
        
        let hasEnhancedData = personInfo != nil
        if hasEnhancedData {
            print("✅ Using enhanced data for \(credit.name.displayName)")
        } else {
            print("📋 Using credits data for \(credit.name.displayName)")
        }
        
        return IMDbPerson(
            id: credit.name.id,
            displayName: credit.name.displayName,
            birthYear: birthYear,
            birthLocation: birthLocation,
            deathYear: deathYear,
            deathLocation: deathLocation,
            deadReason: deadReason,
            knownFor: knownForTitles?.isEmpty == false ? knownForTitles : nil,
            avatars: credit.name.primaryImage != nil ? [IMDbAvatar(
                url: credit.name.primaryImage!.url,
                width: credit.name.primaryImage!.width,
                height: credit.name.primaryImage!.height
            )] : nil
        )
    }
    
    private func convertToPerson(credit: RESTCredit, personInfo: RESTPersonInfo?, knownFor: RESTKnownForResponse?) -> IMDbPerson {
        // Debug logging
        let hasKnownFor = knownFor?.knownFor.isEmpty == false
        
        print("📝 Converting \(credit.name.displayName): birth=\(personInfo?.birthDate?.year ?? 0), location=\(personInfo?.birthLocation ?? "none"), knownFor=\(hasKnownFor)")
        
        // Convert known for data to IMDbTitle format
        let knownForTitles: [IMDbTitle]? = knownFor?.knownFor.compactMap { (knownForCredit: RESTKnownForCredit) -> IMDbTitle? in
            guard let title = knownForCredit.title else { return nil }
            return IMDbTitle(
                id: title.id,
                primaryTitle: title.primaryTitle,
                startYear: title.startYear,
                rating: title.rating != nil ? IMDbRating(
                    aggregateRating: title.rating!.aggregateRating,
                    votesCount: title.rating!.votesCount
                ) : nil
            )
        }
        
        return IMDbPerson(
            id: credit.name.id,
            displayName: credit.name.displayName,
            birthYear: personInfo?.birthDate?.year,
            birthLocation: personInfo?.birthLocation,
            deathYear: personInfo?.deathDate?.year,
            deathLocation: personInfo?.deathLocation,
            deadReason: personInfo?.deathReason,
            knownFor: knownForTitles?.isEmpty == false ? knownForTitles : nil,
            avatars: credit.name.primaryImage != nil ? [IMDbAvatar(
                url: credit.name.primaryImage!.url,
                width: credit.name.primaryImage!.width,
                height: credit.name.primaryImage!.height
            )] : nil
        )
    }
    
    private func convertToBasicPerson(credit: RESTCredit) -> IMDbPerson {
        return IMDbPerson(
            id: credit.name.id,
            displayName: credit.name.displayName,
            birthYear: nil,
            birthLocation: nil,
            deathYear: nil,
            deathLocation: nil,
            deadReason: nil,
            knownFor: nil,
            avatars: credit.name.primaryImage != nil ? [IMDbAvatar(
                url: credit.name.primaryImage!.url,
                width: credit.name.primaryImage!.width,
                height: credit.name.primaryImage!.height
            )] : nil
        )
    }
    
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

// MARK: - REST API Models

struct RESTTitleInfo: Codable {
    let id: String
    let type: String
    let primaryTitle: String
    let primaryImage: RESTImage?
    let genres: [String]
    let rating: RESTRating?
    let startYear: Int
    let runtimeMinutes: Int?
    let plot: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, genres, rating, plot
        case primaryTitle = "primary_title"
        case primaryImage = "primary_image"
        case startYear = "start_year"
        case runtimeMinutes = "runtime_minutes"
    }
}

struct RESTImage: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct RESTRating: Codable {
    let aggregateRating: Double
    let votesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case aggregateRating = "aggregate_rating"
        case votesCount = "votes_count"
    }
}

struct RESTCreditsResponse: Codable {
    var credits: [RESTCredit]
    let nextPageToken: String?
    
    enum CodingKeys: String, CodingKey {
        case credits
        case nextPageToken = "next_page_token"
    }
}

struct RESTCredit: Codable {
    let name: RESTName
    let category: String
    let characters: [String]?
}

struct RESTName: Codable {
    let id: String
    let displayName: String
    let primaryImage: RESTImage?
    let alternativeNames: [String]?
    let primaryProfessions: [String]?
    let biography: String?
    let birthName: String?
    let birthDate: RESTBirthDate?
    let birthLocation: String?
    let deathDate: RESTBirthDate?
    let deathLocation: String?
    let deathReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id, biography
        case displayName = "display_name"
        case primaryImage = "primary_image"
        case alternativeNames = "alternative_names"
        case primaryProfessions = "primary_professions"
        case birthName = "birth_name"
        case birthDate = "birth_date"
        case birthLocation = "birth_location"
        case deathDate = "death_date"
        case deathLocation = "death_location"
        case deathReason = "death_reason"
    }
}

struct RESTPersonInfo: Codable {
    let id: String
    let displayName: String
    let primaryImage: RESTImage?
    let alternativeNames: [String]?
    let primaryProfessions: [String]?
    let biography: String?
    let birthName: String?
    let birthDate: RESTBirthDate?
    let birthLocation: String?
    let deathDate: RESTBirthDate? // Using same structure as birth date
    let deathLocation: String?
    let deathReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id, biography
        case displayName = "display_name"
        case primaryImage = "primary_image"
        case alternativeNames = "alternative_names"
        case primaryProfessions = "primary_professions"
        case birthName = "birth_name"
        case birthDate = "birth_date"
        case birthLocation = "birth_location"
        case deathDate = "death_date"
        case deathLocation = "death_location"
        case deathReason = "death_reason"
    }
}

struct RESTBirthDate: Codable {
    let year: Int?
    let month: Int?
    let day: Int?
}

struct RESTKnownForResponse: Codable {
    let knownFor: [RESTKnownForCredit]
    let nextPageToken: String?
    
    enum CodingKeys: String, CodingKey {
        case knownFor = "known_for"
        case nextPageToken = "next_page_token"
    }
}

struct RESTKnownForCredit: Codable {
    let title: RESTKnownForTitle?
    let category: String?
    let characters: [String]?
    let episodesCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case title, category, characters
        case episodesCount = "episodes_count"
    }
}

struct RESTKnownForTitle: Codable {
    let id: String
    let type: String?
    let primaryTitle: String
    let originalTitle: String?
    let primaryImage: RESTImage?
    let genres: [String]?
    let rating: RESTRating?
    let startYear: Int?
    let endYear: Int?
    let runtimeMinutes: Int?
    let plot: String?
    let isAdult: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, type, genres, rating, plot
        case primaryTitle = "primary_title"
        case originalTitle = "original_title"
        case primaryImage = "primary_image"
        case startYear = "start_year"
        case endYear = "end_year"
        case runtimeMinutes = "runtime_minutes"
        case isAdult = "is_adult"
    }
} 