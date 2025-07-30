# Replace TMDB API with Free IMDb API for Actor Filmography

## Overview
Replace TMDB API usage with a free, no-API-key IMDb service that provides comprehensive actor filmography data. Based on the working implementation in the `yarr` project.

## API Options

### Option 1: IMDb REST API (Recommended for new implementations)
- **Base URL**: `https://rest.imdbapi.dev/v2`
- **Method**: Standard HTTP GET requests
- **Authentication**: None required
- **Easier to implement and debug**

### Option 2: IMDb GraphQL API (More efficient but complex)
- **Base URL**: `https://graph.imdbapi.dev/v1`
- **Method**: POST with GraphQL queries
- **Authentication**: None required
- **Gets all data in fewer requests**

## Implementation Guide

### Step 1: Create the Service Class

```swift
import Foundation

@MainActor
class IMDbService: ObservableObject {
    private let baseURL = "https://rest.imdbapi.dev/v2"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    enum IMDbError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError(Error)
        case networkError(Error)
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .noData: return "No data received"
            case .decodingError(let error): return "Failed to decode: \(error.localizedDescription)"
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .httpError(let code): return "HTTP error: \(code)"
            }
        }
    }
}
```

### Step 2: Define Data Models

```swift
// MARK: - Core Models
struct IMDbPerson: Codable, Identifiable {
    let id: String
    let displayName: String
    let birthYear: Int?
    let birthLocation: String?
    let deathYear: Int?
    let biography: String?
    let knownFor: [IMDbTitle]?  // Actor's filmography
    let primaryImage: IMDbImage?

    enum CodingKeys: String, CodingKey {
        case id, biography
        case displayName = "display_name"
        case birthYear = "birth_year"
        case birthLocation = "birth_location"
        case deathYear = "death_year"
        case knownFor = "known_for"
        case primaryImage = "primary_image"
    }
}

struct IMDbTitle: Codable, Identifiable {
    let id: String
    let primaryTitle: String
    let startYear: Int?
    let genres: [String]?
    let rating: IMDbRating?
    let primaryImage: IMDbImage?

    enum CodingKeys: String, CodingKey {
        case id, genres, rating
        case primaryTitle = "primary_title"
        case startYear = "start_year"
        case primaryImage = "primary_image"
    }
}

struct IMDbRating: Codable {
    let aggregateRating: Double
    let votesCount: Int

    enum CodingKeys: String, CodingKey {
        case aggregateRating = "aggregate_rating"
        case votesCount = "votes_count"
    }
}

struct IMDbImage: Codable {
    let url: String
    let width: Int
    let height: Int
}

// MARK: - API Response Models
struct PersonResponse: Codable {
    let id: String
    let displayName: String
    let birthDate: BirthDate?
    let birthLocation: String?
    let deathDate: BirthDate?
    let biography: String?
    let primaryImage: IMDbImage?

    enum CodingKeys: String, CodingKey {
        case id, biography
        case displayName = "display_name"
        case birthDate = "birth_date"
        case birthLocation = "birth_location"
        case deathDate = "death_date"
        case primaryImage = "primary_image"
    }
}

struct BirthDate: Codable {
    let year: Int?
    let month: Int?
    let day: Int?
}

struct KnownForResponse: Codable {
    let knownFor: [KnownForCredit]

    enum CodingKeys: String, CodingKey {
        case knownFor = "known_for"
    }
}

struct KnownForCredit: Codable {
    let title: KnownForTitle?
    let category: String?
}

struct KnownForTitle: Codable {
    let id: String
    let primaryTitle: String
    let startYear: Int?
    let genres: [String]?
    let rating: IMDbRating?
    let primaryImage: IMDbImage?

    enum CodingKeys: String, CodingKey {
        case id, genres, rating
        case primaryTitle = "primary_title"
        case startYear = "start_year"
        case primaryImage = "primary_image"
    }
}
```

### Step 3: API Methods

```swift
extension IMDbService {

    // Get actor details by IMDb name ID (nm0000001 format)
    func fetchActorDetails(nameID: String) async throws -> IMDbPerson {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("YourApp/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw IMDbError.httpError(httpResponse.statusCode)
            }

            let personResponse = try JSONDecoder().decode(PersonResponse.self, from: data)

            // Get their filmography
            let knownFor = try await fetchActorFilmography(nameID: nameID)

            // Convert to unified model
            return IMDbPerson(
                id: personResponse.id,
                displayName: personResponse.displayName,
                birthYear: personResponse.birthDate?.year,
                birthLocation: personResponse.birthLocation,
                deathYear: personResponse.deathDate?.year,
                biography: personResponse.biography,
                knownFor: knownFor,
                primaryImage: personResponse.primaryImage
            )

        } catch let error as DecodingError {
            throw IMDbError.decodingError(error)
        } catch let error as IMDbError {
            throw error
        } catch {
            throw IMDbError.networkError(error)
        }
    }

    // Get actor's filmography (their other movies)
    func fetchActorFilmography(nameID: String, limit: Int = 10) async throws -> [IMDbTitle] {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/known_for?page_size=\(limit)") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("YourApp/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw IMDbError.httpError(httpResponse.statusCode)
            }

            let knownForResponse = try JSONDecoder().decode(KnownForResponse.self, from: data)

            // Convert to IMDbTitle format
            return knownForResponse.knownFor.compactMap { credit in
                guard let title = credit.title else { return nil }

                return IMDbTitle(
                    id: title.id,
                    primaryTitle: title.primaryTitle,
                    startYear: title.startYear,
                    genres: title.genres,
                    rating: title.rating,
                    primaryImage: title.primaryImage
                )
            }

        } catch let error as DecodingError {
            throw IMDbError.decodingError(error)
        } catch let error as IMDbError {
            throw error
        } catch {
            throw IMDbError.networkError(error)
        }
    }

    // Search for actors by name
    func searchActors(query: String) async throws -> [IMDbPerson] {
        // Note: This API doesn't have direct person search, so you'd need to:
        // 1. Search movies/shows first: GET /search/titles?q={query}
        // 2. Extract cast from results
        // 3. Filter for actors matching the name

        guard let url = URL(string: "\(baseURL)/search/titles?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw IMDbError.invalidURL
        }

        // Implementation would depend on your specific search needs
        // This is a simplified example

        return [] // Placeholder
    }
}
```

### Step 4: Usage Examples

```swift
// In your view model or controller:
class ActorDetailViewModel: ObservableObject {
    @Published var actor: IMDbPerson?
    @Published var filmography: [IMDbTitle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let imdbService = IMDbService()

    func loadActor(nameID: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let actorDetails = try await imdbService.fetchActorDetails(nameID: nameID)

            await MainActor.run {
                self.actor = actorDetails
                self.filmography = actorDetails.knownFor ?? []
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// In your SwiftUI view:
struct ActorDetailView: View {
    let actorNameID: String
    @StateObject private var viewModel = ActorDetailViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading actor details...")
            } else if let actor = viewModel.actor {
                VStack(alignment: .leading) {
                    Text(actor.displayName)
                        .font(.title)

                    if let birthYear = actor.birthYear {
                        Text("Born: \(birthYear)")
                    }

                    if let biography = actor.biography {
                        Text(biography)
                            .padding(.top)
                    }

                    Text("Known For:")
                        .font(.headline)
                        .padding(.top)

                    ForEach(viewModel.filmography) { movie in
                        HStack {
                            Text(movie.primaryTitle)
                            Spacer()
                            if let year = movie.startYear {
                                Text("(\(year))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
        .task {
            await viewModel.loadActor(nameID: actorNameID)
        }
    }
}
```

### Step 5: Migration from TMDB

To replace your TMDB usage:

1. **Replace TMDB actor ID with IMDb name ID**: IMDb uses format `nm0000001` instead of numeric IDs
2. **Update data models**: Use the IMDb models above instead of TMDB models
3. **Replace API calls**: Use `fetchActorDetails()` and `fetchActorFilmography()` instead of TMDB endpoints
4. **Remove API key configuration**: No authentication needed
5. **Update error handling**: Use the new `IMDbError` types

### Key Advantages Over TMDB

- ✅ **No API key required** - completely free
- ✅ **No rate limiting** (reasonable usage)
- ✅ **Rich biographical data** - birth/death info, locations, biography
- ✅ **High-quality ratings** - IMDb ratings are authoritative
- ✅ **Comprehensive filmography** - includes ratings and years
- ✅ **Images included** - actor photos and movie posters

### Rate Limiting Considerations

While no API key is required, be respectful:
- Add delays between requests (200ms recommended)
- Cache responses when possible
- Use reasonable page sizes (≤20 items)

Since you're working with Plex, you'll get actor names but not IMDb IDs directly. Looking at the [Plex API documentation](https://www.plexopedia.com/plex-media-server/api/), there are a couple of approaches to bridge this gap.

## Approach 1: Get IMDb IDs from Plex (Recommended)

Plex often stores external IDs (including IMDb) in its metadata. You can extract these using Plex's movie details API:

### Get Movie Details with External IDs

```swift
// Plex API Service Extension
extension PlexService {

    // Get movie details including external IDs and cast
    func getMovieDetails(movieKey: String) async throws -> PlexMovieDetails {
        guard let url = URL(string: "\(plexServerURL)/library/metadata/\(movieKey)?X-Plex-Token=\(plexToken)") else {
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(PlexMovieResponse.self, from: data)

        return response.mediaContainer.metadata.first ?? PlexMovieDetails()
    }
}

// Plex Response Models
struct PlexMovieResponse: Codable {
    let mediaContainer: PlexMediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

struct PlexMediaContainer: Codable {
    let metadata: [PlexMovieDetails]

    enum CodingKeys: String, CodingKey {
        case metadata = "Metadata"
    }
}

struct PlexMovieDetails: Codable {
    let title: String?
    let year: Int?
    let guid: String? // Contains external IDs like imdb://tt1234567
    let role: [PlexRole]? // Cast information

    enum CodingKeys: String, CodingKey {
        case title, year, guid
        case role = "Role"
    }

    // Extract IMDb ID from guid
    var imdbID: String? {
        guard let guid = guid else { return nil }

        // Plex stores IMDb IDs in formats like:
        // "plex://movie/5d776b59ad5437001f79c6f8"
        // "imdb://tt1234567"
        // "com.plexapp.agents.imdb://tt1234567?lang=en"

        if guid.contains("imdb://") {
            return guid.components(separatedBy: "imdb://").last?.components(separatedBy: "?").first
        } else if guid.contains("agents.imdb://") {
            return guid.components(separatedBy: "agents.imdb://").last?.components(separatedBy: "?").first
        }

        return nil
    }
}

struct PlexRole: Codable {
    let tag: String // Actor name
    let role: String? // Character name
    let thumb: String? // Actor photo URL
}
```

## Approach 2: Search IMDb by Actor Name (Fallback)

When IMDb IDs aren't available from Plex, search by name:

```swift
extension IMDbService {

    // Search for actor by name and return best match
    func findActorByName(_ name: String) async throws -> IMDbPerson? {
        // Since IMDb REST API doesn't have direct person search,
        // we'll use a workaround: search for movies they're known for,
        // then extract cast information

        let searchResults = try await searchTitlesForActor(name)
        return try await findActorInSearchResults(name, from: searchResults)
    }

    private func searchTitlesForActor(_ actorName: String) async throws -> [IMDbTitle] {
        guard let encodedName = actorName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/titles?q=\(encodedName)&page_size=10") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("YourApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(TitleSearchResponse.self, from: data)
        return searchResponse.results
    }

    private func findActorInSearchResults(_ actorName: String, from titles: [IMDbTitle]) async throws -> IMDbPerson? {
        // Search through movie casts to find the actor
        for title in titles {
            if let cast = try? await fetchMovieCast(titleID: title.id) {
                if let actor = cast.first(where: { actor in
                    actor.displayName.lowercased().contains(actorName.lowercased()) ||
                    actorName.lowercased().contains(actor.displayName.lowercased())
                }) {
                    // Found the actor, now get their full details
                    return try await fetchActorDetails(nameID: actor.id)
                }
            }

            // Add small delay to be respectful to the API
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        return nil
    }

    private func fetchMovieCast(titleID: String) async throws -> [IMDbPerson] {
        guard let url = URL(string: "\(baseURL)/titles/\(titleID)/credits") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("YourApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let creditsResponse = try JSONDecoder().decode(CreditsResponse.self, from: data)

        return creditsResponse.credits
            .filter { $0.category == "ACTOR" || $0.category == "ACTRESS" }
            .map { credit in
                IMDbPerson(
                    id: credit.name.id,
                    displayName: credit.name.displayName,
                    birthYear: nil,
                    birthLocation: nil,
                    deathYear: nil,
                    biography: nil,
                    knownFor: nil,
                    primaryImage: credit.name.primaryImage
                )
            }
    }
}

// Additional models for search
struct TitleSearchResponse: Codable {
    let results: [IMDbTitle]
}

struct CreditsResponse: Codable {
    let credits: [Credit]
}

struct Credit: Codable {
    let name: CreditName
    let category: String
}

struct CreditName: Codable {
    let id: String
    let displayName: String
    let primaryImage: IMDbImage?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case primaryImage = "primary_image"
    }
}
```

## Complete Integration: Plex → IMDb

```swift
class MovieActorService: ObservableObject {
    private let plexService = PlexService()
    private let imdbService = IMDbService()

    func getActorFilmography(from plexMovieKey: String, actorName: String) async throws -> IMDbPerson? {
        // Step 1: Try to get IMDb ID from Plex metadata
        let plexMovie = try await plexService.getMovieDetails(movieKey: plexMovieKey)

        if let imdbID = plexMovie.imdbID {
            // Step 2a: If we have IMDb movie ID, search for the actor in that movie's cast
            if let actorID = try await findActorInMovie(imdbMovieID: imdbID, actorName: actorName) {
                return try await imdbService.fetchActorDetails(nameID: actorID)
            }
        }

        // Step 2b: Fallback - search IMDb by actor name
        return try await imdbService.findActorByName(actorName)
    }

    private func findActorInMovie(imdbMovieID: String, actorName: String) async throws -> String? {
        guard let url = URL(string: "\(imdbService.baseURL)/titles/\(imdbMovieID)/credits") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("YourApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let creditsResponse = try JSONDecoder().decode(CreditsResponse.self, from: data)

        // Find actor by name match
        let actor = creditsResponse.credits.first { credit in
            (credit.category == "ACTOR" || credit.category == "ACTRESS") &&
            (credit.name.displayName.lowercased().contains(actorName.lowercased()) ||
             actorName.lowercased().contains(credit.name.displayName.lowercased()))
        }

        return actor?.name.id
    }
}
```

## Usage Example

```swift
struct ActorDetailView: View {
    let plexMovieKey: String
    let actorName: String

    @StateObject private var actorService = MovieActorService()
    @State private var actor: IMDbPerson?
    @State private var isLoading = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Finding \(actorName)'s filmography...")
            } else if let actor = actor {
                VStack(alignment: .leading) {
                    Text(actor.displayName)
                        .font(.title)

                    Text("Other Movies:")
                        .font(.headline)

                    ForEach(actor.knownFor ?? [], id: \.id) { movie in
                        HStack {
                            Text(movie.primaryTitle)
                            Spacer()
                            if let year = movie.startYear {
                                Text("(\(year))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("Actor not found")
            }
        }
        .task {
            isLoading = true
            actor = try? await actorService.getActorFilmography(
                from: plexMovieKey,
                actorName: actorName
            )
            isLoading = false
        }
    }
}
```

## Key Points

1. **Primary approach**: Extract IMDb IDs from Plex's `guid` field when available
2. **Fallback approach**: Search IMDb by actor name when IMDb IDs aren't available
3. **No API keys needed**: Both Plex (your server) and IMDb API are free
4. **Respectful usage**: Includes delays between requests to avoid rate limiting

The Plex API documentation at [plexopedia.com](https://www.plexopedia.com/plex-media-server/api/) shows that movie metadata often includes external IDs, which should give you the IMDb IDs you need for most content, making the name-based search only necessary as a fallback.

