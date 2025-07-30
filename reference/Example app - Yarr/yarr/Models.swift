//
//  Models.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation

// MARK: - API Response Models

// MARK: - Pagination Result
struct MovieListResult {
    let movies: [Movie]
    let totalCount: Int
    let currentPage: Int
    let limit: Int
    let totalPages: Int
    
    init(movies: [Movie], totalCount: Int, currentPage: Int, limit: Int) {
        self.movies = movies
        self.totalCount = totalCount
        self.currentPage = currentPage
        self.limit = limit
        self.totalPages = max(1, Int(ceil(Double(totalCount) / Double(limit))))
    }
}

struct MovieListResponse: Codable {
    let status: String
    let statusMessage: String
    let data: MovieListData
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusMessage = "status_message"
        case data
    }
}

struct MovieListData: Codable {
    let movieCount: Int
    let limit: Int
    let pageNumber: Int
    let movies: [Movie]?
    
    enum CodingKeys: String, CodingKey {
        case movieCount = "movie_count"
        case limit
        case pageNumber = "page_number"
        case movies
    }
}

struct MovieDetailsResponse: Codable {
    let status: String
    let statusMessage: String
    let data: MovieDetailsData
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusMessage = "status_message"
        case data
    }
}

struct MovieDetailsData: Codable {
    let movie: MovieDetails
}

struct MovieSuggestionsResponse: Codable {
    let status: String
    let statusMessage: String
    let data: MovieSuggestionsData
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusMessage = "status_message"
        case data
    }
}

struct MovieSuggestionsData: Codable {
    let movieCount: Int
    let movies: [Movie]?
    
    enum CodingKeys: String, CodingKey {
        case movieCount = "movie_count"
        case movies
    }
}

// MARK: - Movie Models

struct Movie: Codable, Identifiable {
    let id: Int
    let url: String?
    let imdbCode: String?
    let title: String?
    let titleEnglish: String?
    let titleLong: String?
    let slug: String?
    let year: Int?
    let rating: Double?
    let runtime: Int?
    let genres: [String]
    let summary: String?
    let descriptionFull: String?
    let synopsis: String?
    let ytTrailerCode: String?
    let language: String?
    let mpaRating: String?
    let backgroundImage: String?
    let backgroundImageOriginal: String?
    let smallCoverImage: String?
    let mediumCoverImage: String?
    let largeCoverImage: String?
    let state: String?
    let torrents: [Torrent]
    let dateUploaded: String?
    let dateUploadedUnix: Int?
    
    // Computed properties for safe access with defaults
    var safeTitle: String {
        return title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title! : 
               titleEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? titleEnglish! :
               titleLong?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? titleLong! :
               "Unknown Title"
    }
    
    var safeYear: Int {
        return year ?? 0
    }
    
    var safeRating: Double {
        return rating ?? 0.0
    }
    
    var isValid: Bool {
        // A movie is considered valid if it has at least an ID, some form of title, and year
        return id > 0 && !safeTitle.isEmpty && safeYear > 0
    }
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, year, rating, runtime, genres, summary, synopsis, language, state, torrents
        case imdbCode = "imdb_code"
        case titleEnglish = "title_english"
        case titleLong = "title_long"
        case slug
        case descriptionFull = "description_full"
        case ytTrailerCode = "yt_trailer_code"
        case mpaRating = "mpa_rating"
        case backgroundImage = "background_image"
        case backgroundImageOriginal = "background_image_original"
        case smallCoverImage = "small_cover_image"
        case mediumCoverImage = "medium_cover_image"
        case largeCoverImage = "large_cover_image"
        case dateUploaded = "date_uploaded"
        case dateUploadedUnix = "date_uploaded_unix"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode ID - if it fails or is invalid, create a placeholder that will be filtered out
        if let decodedId = try? container.decode(Int.self, forKey: .id), decodedId > 0 {
            self.id = decodedId
        } else {
            // Create a placeholder with invalid ID that will be filtered out by isValid
            self.id = -1
            print("⚠️ Found movie with invalid/missing ID - will be filtered out")
        }
        
        // Handle all other fields gracefully with nil coalescing
        self.url = try? container.decode(String.self, forKey: .url)
        self.imdbCode = try? container.decode(String.self, forKey: .imdbCode)
        self.title = try? container.decode(String.self, forKey: .title)
        self.titleEnglish = try? container.decode(String.self, forKey: .titleEnglish)
        self.titleLong = try? container.decode(String.self, forKey: .titleLong)
        self.slug = try? container.decode(String.self, forKey: .slug)
        self.year = try? container.decode(Int.self, forKey: .year)
        self.rating = try? container.decode(Double.self, forKey: .rating)
        self.runtime = try? container.decode(Int.self, forKey: .runtime)
        self.genres = (try? container.decode([String].self, forKey: .genres)) ?? []
        self.summary = try? container.decode(String.self, forKey: .summary)
        self.descriptionFull = try? container.decode(String.self, forKey: .descriptionFull)
        self.synopsis = try? container.decode(String.self, forKey: .synopsis)
        self.ytTrailerCode = try? container.decode(String.self, forKey: .ytTrailerCode)
        self.language = try? container.decode(String.self, forKey: .language)
        self.mpaRating = try? container.decode(String.self, forKey: .mpaRating)
        self.backgroundImage = try? container.decode(String.self, forKey: .backgroundImage)
        self.backgroundImageOriginal = try? container.decode(String.self, forKey: .backgroundImageOriginal)
        self.smallCoverImage = try? container.decode(String.self, forKey: .smallCoverImage)
        self.mediumCoverImage = try? container.decode(String.self, forKey: .mediumCoverImage)
        self.largeCoverImage = try? container.decode(String.self, forKey: .largeCoverImage)
        self.state = try? container.decode(String.self, forKey: .state)
        self.torrents = (try? container.decode([Torrent].self, forKey: .torrents)) ?? []
        self.dateUploaded = try? container.decode(String.self, forKey: .dateUploaded)
        self.dateUploadedUnix = try? container.decode(Int.self, forKey: .dateUploadedUnix)
    }
    
    // Regular initializer for previews and tests
    init(
        id: Int,
        url: String? = nil,
        imdbCode: String? = nil,
        title: String? = nil,
        titleEnglish: String? = nil,
        titleLong: String? = nil,
        slug: String? = nil,
        year: Int? = nil,
        rating: Double? = nil,
        runtime: Int? = nil,
        genres: [String] = [],
        summary: String? = nil,
        descriptionFull: String? = nil,
        synopsis: String? = nil,
        ytTrailerCode: String? = nil,
        language: String? = nil,
        mpaRating: String? = nil,
        backgroundImage: String? = nil,
        backgroundImageOriginal: String? = nil,
        smallCoverImage: String? = nil,
        mediumCoverImage: String? = nil,
        largeCoverImage: String? = nil,
        state: String? = nil,
        torrents: [Torrent] = [],
        dateUploaded: String? = nil,
        dateUploadedUnix: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.imdbCode = imdbCode
        self.title = title
        self.titleEnglish = titleEnglish
        self.titleLong = titleLong
        self.slug = slug
        self.year = year
        self.rating = rating
        self.runtime = runtime
        self.genres = genres
        self.summary = summary
        self.descriptionFull = descriptionFull
        self.synopsis = synopsis
        self.ytTrailerCode = ytTrailerCode
        self.language = language
        self.mpaRating = mpaRating
        self.backgroundImage = backgroundImage
        self.backgroundImageOriginal = backgroundImageOriginal
        self.smallCoverImage = smallCoverImage
        self.mediumCoverImage = mediumCoverImage
        self.largeCoverImage = largeCoverImage
        self.state = state
        self.torrents = torrents
        self.dateUploaded = dateUploaded
        self.dateUploadedUnix = dateUploadedUnix
    }
}

struct MovieDetails: Codable {
    let id: Int
    let url: String?
    let imdbCode: String?
    let title: String?
    let titleEnglish: String?
    let titleLong: String?
    let slug: String?
    let year: Int?
    let rating: Double?
    let runtime: Int?
    let genres: [String]
    let likeCount: Int?
    let descriptionIntro: String?
    let descriptionFull: String?
    let ytTrailerCode: String?
    let language: String?
    let mpaRating: String?
    let backgroundImage: String?
    let backgroundImageOriginal: String?
    let smallCoverImage: String?
    let mediumCoverImage: String?
    let largeCoverImage: String?
    let mediumScreenshotImage1: String?
    let mediumScreenshotImage2: String?
    let mediumScreenshotImage3: String?
    let largeScreenshotImage1: String?
    let largeScreenshotImage2: String?
    let largeScreenshotImage3: String?
    let cast: [CastMember]?
    let torrents: [Torrent]
    let dateUploaded: String?
    let dateUploadedUnix: Int?
    
    // Computed properties for safe access with defaults
    var safeTitle: String {
        return title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title! : 
               titleEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? titleEnglish! :
               titleLong?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? titleLong! :
               "Unknown Title"
    }
    
    var safeYear: Int {
        return year ?? 0
    }
    
    var safeRating: Double {
        return rating ?? 0.0
    }
    
    // Computed properties for backward compatibility
    var summary: String {
        return descriptionIntro ?? descriptionFull ?? ""
    }
    
    var synopsis: String {
        return descriptionFull ?? descriptionIntro ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, year, rating, runtime, genres, language, torrents, cast
        case imdbCode = "imdb_code"
        case titleEnglish = "title_english"
        case titleLong = "title_long"
        case slug
        case likeCount = "like_count"
        case descriptionIntro = "description_intro"
        case descriptionFull = "description_full"
        case ytTrailerCode = "yt_trailer_code"
        case mpaRating = "mpa_rating"
        case backgroundImage = "background_image"
        case backgroundImageOriginal = "background_image_original"
        case smallCoverImage = "small_cover_image"
        case mediumCoverImage = "medium_cover_image"
        case largeCoverImage = "large_cover_image"
        case mediumScreenshotImage1 = "medium_screenshot_image1"
        case mediumScreenshotImage2 = "medium_screenshot_image2"
        case mediumScreenshotImage3 = "medium_screenshot_image3"
        case largeScreenshotImage1 = "large_screenshot_image1"
        case largeScreenshotImage2 = "large_screenshot_image2"
        case largeScreenshotImage3 = "large_screenshot_image3"
        case dateUploaded = "date_uploaded"
        case dateUploadedUnix = "date_uploaded_unix"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode ID - if it fails or is invalid, create a placeholder that will be filtered out
        if let decodedId = try? container.decode(Int.self, forKey: .id), decodedId > 0 {
            self.id = decodedId
        } else {
            // For movie details, this is more serious, but still don't crash the whole response
            self.id = -1
            print("⚠️ Found movie details with invalid/missing ID - using placeholder")
        }
        
        // Handle all other fields gracefully
        self.url = try? container.decode(String.self, forKey: .url)
        self.imdbCode = try? container.decode(String.self, forKey: .imdbCode)
        self.title = try? container.decode(String.self, forKey: .title)
        self.titleEnglish = try? container.decode(String.self, forKey: .titleEnglish)
        self.titleLong = try? container.decode(String.self, forKey: .titleLong)
        self.slug = try? container.decode(String.self, forKey: .slug)
        self.year = try? container.decode(Int.self, forKey: .year)
        self.rating = try? container.decode(Double.self, forKey: .rating)
        self.runtime = try? container.decode(Int.self, forKey: .runtime)
        self.genres = (try? container.decode([String].self, forKey: .genres)) ?? []
        self.likeCount = try? container.decode(Int.self, forKey: .likeCount)
        self.descriptionIntro = try? container.decode(String.self, forKey: .descriptionIntro)
        self.descriptionFull = try? container.decode(String.self, forKey: .descriptionFull)
        self.ytTrailerCode = try? container.decode(String.self, forKey: .ytTrailerCode)
        self.language = try? container.decode(String.self, forKey: .language)
        self.mpaRating = try? container.decode(String.self, forKey: .mpaRating)
        self.backgroundImage = try? container.decode(String.self, forKey: .backgroundImage)
        self.backgroundImageOriginal = try? container.decode(String.self, forKey: .backgroundImageOriginal)
        self.smallCoverImage = try? container.decode(String.self, forKey: .smallCoverImage)
        self.mediumCoverImage = try? container.decode(String.self, forKey: .mediumCoverImage)
        self.largeCoverImage = try? container.decode(String.self, forKey: .largeCoverImage)
        self.mediumScreenshotImage1 = try? container.decode(String.self, forKey: .mediumScreenshotImage1)
        self.mediumScreenshotImage2 = try? container.decode(String.self, forKey: .mediumScreenshotImage2)
        self.mediumScreenshotImage3 = try? container.decode(String.self, forKey: .mediumScreenshotImage3)
        self.largeScreenshotImage1 = try? container.decode(String.self, forKey: .largeScreenshotImage1)
        self.largeScreenshotImage2 = try? container.decode(String.self, forKey: .largeScreenshotImage2)
        self.largeScreenshotImage3 = try? container.decode(String.self, forKey: .largeScreenshotImage3)
        self.cast = try? container.decode([CastMember].self, forKey: .cast)
        self.torrents = (try? container.decode([Torrent].self, forKey: .torrents)) ?? []
        self.dateUploaded = try? container.decode(String.self, forKey: .dateUploaded)
        self.dateUploadedUnix = try? container.decode(Int.self, forKey: .dateUploadedUnix)
    }
    
    // Regular initializer for previews and tests
    init(
        id: Int,
        url: String? = nil,
        imdbCode: String? = nil,
        title: String? = nil,
        titleEnglish: String? = nil,
        titleLong: String? = nil,
        slug: String? = nil,
        year: Int? = nil,
        rating: Double? = nil,
        runtime: Int? = nil,
        genres: [String] = [],
        likeCount: Int? = nil,
        descriptionIntro: String? = nil,
        descriptionFull: String? = nil,
        ytTrailerCode: String? = nil,
        language: String? = nil,
        mpaRating: String? = nil,
        backgroundImage: String? = nil,
        backgroundImageOriginal: String? = nil,
        smallCoverImage: String? = nil,
        mediumCoverImage: String? = nil,
        largeCoverImage: String? = nil,
        mediumScreenshotImage1: String? = nil,
        mediumScreenshotImage2: String? = nil,
        mediumScreenshotImage3: String? = nil,
        largeScreenshotImage1: String? = nil,
        largeScreenshotImage2: String? = nil,
        largeScreenshotImage3: String? = nil,
        cast: [CastMember]? = nil,
        torrents: [Torrent] = [],
        dateUploaded: String? = nil,
        dateUploadedUnix: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.imdbCode = imdbCode
        self.title = title
        self.titleEnglish = titleEnglish
        self.titleLong = titleLong
        self.slug = slug
        self.year = year
        self.rating = rating
        self.runtime = runtime
        self.genres = genres
        self.likeCount = likeCount
        self.descriptionIntro = descriptionIntro
        self.descriptionFull = descriptionFull
        self.ytTrailerCode = ytTrailerCode
        self.language = language
        self.mpaRating = mpaRating
        self.backgroundImage = backgroundImage
        self.backgroundImageOriginal = backgroundImageOriginal
        self.smallCoverImage = smallCoverImage
        self.mediumCoverImage = mediumCoverImage
        self.largeCoverImage = largeCoverImage
        self.mediumScreenshotImage1 = mediumScreenshotImage1
        self.mediumScreenshotImage2 = mediumScreenshotImage2
        self.mediumScreenshotImage3 = mediumScreenshotImage3
        self.largeScreenshotImage1 = largeScreenshotImage1
        self.largeScreenshotImage2 = largeScreenshotImage2
        self.largeScreenshotImage3 = largeScreenshotImage3
        self.cast = cast
        self.torrents = torrents
        self.dateUploaded = dateUploaded
        self.dateUploadedUnix = dateUploadedUnix
    }
}

struct Torrent: Codable, Identifiable {
    let id = UUID()
    let url: String
    let hash: String
    let quality: String
    let type: String?
    let isRepack: String?
    let videoCodec: String?
    let bitDepth: String?
    let audioChannels: String?
    let seeds: Int
    let peers: Int
    let size: String
    let sizeBytes: Int?
    let dateUploaded: String?
    let dateUploadedUnix: Int?
    
    enum CodingKeys: String, CodingKey {
        case url, hash, quality, type, seeds, peers, size
        case isRepack = "is_repack"
        case videoCodec = "video_codec"
        case bitDepth = "bit_depth"
        case audioChannels = "audio_channels"
        case sizeBytes = "size_bytes"
        case dateUploaded = "date_uploaded"
        case dateUploadedUnix = "date_uploaded_unix"
    }
}

struct CastMember: Codable, Identifiable {
    let id = UUID()
    let name: String
    let characterName: String
    let imdbCode: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case characterName = "character_name"
        case imdbCode = "imdb_code"
    }
}

// MARK: - Movie Filters

class MovieFilters: ObservableObject {
    @Published var quality: String = "All"
    @Published var genre: String = "All"
    @Published var minimumRating: Int = 0
    @Published var sortBy: String = "date_added"
    @Published var orderBy: String = "desc"
    let maxLimit: Int = 50 // Maximum allowed by API
    
    static let qualityOptions = ["All", "480p", "720p", "1080p", "1080p.x265", "2160p", "3D"]
    static let genreOptions = [
        "All", "Action", "Adventure", "Animation", "Biography", "Comedy", "Crime", 
        "Documentary", "Drama", "Family", "Fantasy", "Film-Noir", "History", "Horror", 
        "Music", "Musical", "Mystery", "Romance", "Sci-Fi", "Sport", "Thriller", 
        "War", "Western"
    ]
    static let sortByOptions = [
        ("date_added", "Date Added"),
        ("download_count", "Downloads"),
        ("like_count", "Likes"),
        ("rating", "Rating"),
        ("year", "Year"),
        ("title", "Title")
    ]
    static let orderByOptions = [("desc", "Descending"), ("asc", "Ascending")]
    
    var apiQuality: String? {
        return quality == "All" ? nil : quality
    }
    
    var apiGenre: String? {
        return genre == "All" ? nil : genre
    }
    
    /// Calculate optimal movie count based on screen dimensions for a balanced grid
    func optimalMovieCount(for screenSize: CGSize) -> Int {
        let cardSize = adaptiveCardSize(for: screenSize.width)
        let columns = calculateOptimalColumns(for: screenSize.width, cardSize: cardSize)
        let spacing = adaptiveSpacing(for: screenSize.width)
        
        // Calculate how many rows can fit in the visible screen area
        let availableHeight = screenSize.height - 150 // Account for navigation and controls (reduced from 200)
        let cardHeight = cardSize.height + 50 // Card height + info area (reduced from 60)
        let maxVisibleRows = max(3, Int(availableHeight / (cardHeight + spacing)))
        
        #if DEBUG
        print("📊 optimalMovieCount calculation:")
        print("  - screenSize: \(screenSize)")
        print("  - cardSize: \(cardSize)")
        print("  - columns: \(columns)")
        print("  - spacing: \(spacing)")
        print("  - availableHeight: \(availableHeight)")
        print("  - cardHeight: \(cardHeight)")
        print("  - maxVisibleRows: \(maxVisibleRows)")
        #endif
        
        // Prefer configurations that create complete grids, ordered by movie count (descending)
        let optimalConfigurations = [
            (cols: 2, rows: 25), // 50 movies: 2x25
            (cols: 5, rows: 10), // 50 movies: 5x10
            (cols: 2, rows: 24), // 48 movies: 2x24
            (cols: 3, rows: 16), // 48 movies: 3x16
            (cols: 4, rows: 12), // 48 movies: 4x12
            (cols: 6, rows: 8),  // 48 movies: 6x8
            (cols: 5, rows: 9),  // 45 movies: 5x9
            (cols: 3, rows: 15), // 45 movies: 3x15
            (cols: 6, rows: 7),  // 42 movies: 6x7
            (cols: 4, rows: 10), // 40 movies: 4x10
            (cols: 5, rows: 8),  // 40 movies: 5x8
            (cols: 3, rows: 12), // 36 movies: 3x12
            (cols: 4, rows: 9),  // 36 movies: 4x9
            (cols: 6, rows: 6),  // 36 movies: 6x6
            (cols: 5, rows: 7),  // 35 movies: 5x7
            (cols: 3, rows: 10), // 30 movies: 3x10
            (cols: 5, rows: 6),  // 30 movies: 5x6
            (cols: 2, rows: 15), // 30 movies: 2x15
            (cols: 4, rows: 7),  // 28 movies: 4x7
            (cols: 3, rows: 8),  // 24 movies: 3x8
            (cols: 4, rows: 6),  // 24 movies: 4x6
            (cols: 6, rows: 4),  // 24 movies: 6x4
            (cols: 5, rows: 4),  // 20 movies: 5x4 (current fallback)
        ]
        
        // Find the best configuration that fits the screen
        for config in optimalConfigurations {
            let fitsColumns = config.cols <= columns
            let fitsRows = config.rows <= maxVisibleRows * 4
            
            #if DEBUG
            print("  - Testing config: \(config.cols)x\(config.rows) = \(config.cols * config.rows)")
            print("    - fitsColumns (\(config.cols) <= \(columns)): \(fitsColumns)")
            print("    - fitsRows (\(config.rows) <= \(maxVisibleRows * 4)): \(fitsRows)")
            #endif
            
            if fitsColumns && fitsRows {
                let result = config.cols * config.rows
                #if DEBUG
                print("  ✅ Selected configuration: \(config.cols)x\(config.rows) = \(result) movies")
                #endif
                return result
            }
        }
        
        // Fallback: calculate based on available columns and reasonable row count
        let targetRows = min(maxVisibleRows * 4, 15)
        let fallbackResult = columns * targetRows
        
        #if DEBUG
        print("  🔄 Using fallback calculation:")
        print("    - columns: \(columns)")
        print("    - targetRows: \(targetRows)")
        print("    - result: \(fallbackResult)")
        #endif
        
        return fallbackResult
    }
    
    private func adaptiveCardSize(for width: CGFloat) -> CGSize {
        switch width {
        case 0..<1000:
            return CGSize(width: 140, height: 210)
        case 1000..<1300:
            return CGSize(width: 160, height: 240)
        case 1300..<1600:
            return CGSize(width: 180, height: 270)
        default:
            return CGSize(width: 200, height: 300)
        }
    }
    
    private func calculateOptimalColumns(for width: CGFloat, cardSize: CGSize) -> Int {
        let spacing = adaptiveSpacing(for: width)
        let padding = adaptivePadding(for: width)
        let availableWidth = width - (padding * 2)
        
        let minColumns = 2
        let maxColumns = 6 // Maximum for good UX
        var columns = 1
        
        while columns < maxColumns {
            let totalSpacing = CGFloat(columns - 1) * spacing
            let totalCardWidth = CGFloat(columns) * cardSize.width
            let totalWidth = totalCardWidth + totalSpacing
            
            if totalWidth <= availableWidth {
                columns += 1
            } else {
                break
            }
        }
        
        return max(minColumns, columns - 1)
    }
    
    private func adaptiveSpacing(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<1000: return 16
        case 1000..<1300: return 24
        case 1300..<1600: return 32
        default: return 40
        }
    }
    
    private func adaptivePadding(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<1000: return 16
        case 1000..<1300: return 24
        case 1300..<1600: return 32
        default: return 40
        }
    }
    
    func reset() {
        quality = "All"
        genre = "All"
        minimumRating = 0
        sortBy = "date_added"
        orderBy = "desc"
    }
} 