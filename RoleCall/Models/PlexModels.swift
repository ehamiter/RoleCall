//
//  PlexModels.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import Foundation

// MARK: - Plex Settings Model
struct PlexSettings: Codable {
    var serverIP: String = ""
    var plexToken: String = ""
    var tokenExpirationDate: Date?

    var isTokenValid: Bool {
        guard !plexToken.isEmpty else { return false }
        if let expirationDate = tokenExpirationDate {
            return Date() < expirationDate
        }
        return true // If no expiration date is set, assume it's valid
    }
}

// MARK: - Plex Authentication Response
struct PlexAuthResponse: Codable {
    let user: PlexUser

    struct PlexUser: Codable {
        let id: Int
        let uuid: String
        let email: String
        let title: String
        let username: String
        let authToken: String

        private enum CodingKeys: String, CodingKey {
            case id, uuid, email, title, username
            case authToken = "authToken"
        }
    }
}

// MARK: - Plex Server Capabilities Response
struct PlexCapabilitiesResponse: Codable {
    let mediaContainer: MediaContainer

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let size: Int?
        let allowCameraUpload: Bool?
        let allowChannelAccess: Bool?
        let allowMediaDeletion: Bool?
        let allowSharing: Bool?
        let allowSync: Bool?
        let allowTuners: Bool?
        let backgroundProcessing: Bool?
        let certificate: Bool?
        let companionProxy: Bool?
        let countryCode: String?
        let diagnostics: String?
        let eventStream: Bool?
        let friendlyName: String?
        let hubSearch: Bool?
        let itemClusters: Bool?
        let livetv: Int?
        let machineIdentifier: String?
        let mediaProviders: Bool?
        let multiuser: Bool?
        let myPlex: Bool?
        let myPlexMappingState: String?
        let myPlexSigninState: String?
        let myPlexSubscription: Bool?
        let myPlexUsername: String?
        let offlineTranscode: Int?
        let ownerFeatures: String?
        let photoAutoTag: Bool?
        let platform: String?
        let platformVersion: String?
        let pluginHost: Bool?
        let pushNotifications: Bool?
        let readOnlyLibraries: Bool?
        let streamingBrainABRVersion: Int?
        let streamingBrainVersion: Int?
        let sync: Bool?
        let transcoderActiveVideoSessions: Int?
        let transcoderAudio: Bool?
        let transcoderLyrics: Bool?
        let transcoderPhoto: Bool?
        let transcoderSubtitles: Bool?
        let transcoderVideo: Bool?
        let transcoderVideoBitrates: String?
        let transcoderVideoQualities: String?
        let transcoderVideoResolutions: String?
        let updatedAt: Int?
        let updater: Bool?
        let version: String?
        let voiceSearch: Bool?

        // Directory entries (if any)
        let directory: [Directory]?

        private enum CodingKeys: String, CodingKey {
            case size, allowCameraUpload, allowChannelAccess, allowMediaDeletion, allowSharing, allowSync, allowTuners, backgroundProcessing, certificate, companionProxy, countryCode, diagnostics, eventStream, friendlyName, hubSearch, itemClusters, livetv, machineIdentifier, mediaProviders, multiuser, myPlex, myPlexMappingState, myPlexSigninState, myPlexSubscription, myPlexUsername, offlineTranscode, ownerFeatures, photoAutoTag, platform, platformVersion, pluginHost, pushNotifications, readOnlyLibraries, streamingBrainABRVersion, streamingBrainVersion, sync, transcoderActiveVideoSessions, transcoderAudio, transcoderLyrics, transcoderPhoto, transcoderSubtitles, transcoderVideo, transcoderVideoBitrates, transcoderVideoQualities, transcoderVideoResolutions, updatedAt, updater, version, voiceSearch
            case directory = "Directory"
        }

        struct Directory: Codable {
            let count: Int?
            let key: String?
            let title: String?
        }
    }
}

// MARK: - Plex Activities Response
struct PlexActivitiesResponse: Codable {
    let mediaContainer: ActivitiesContainer

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct ActivitiesContainer: Codable {
        let size: Int
        let activity: [Activity]?

        private enum CodingKeys: String, CodingKey {
            case size
            case activity = "Activity"
        }

        struct Activity: Codable, Identifiable {
            let id: String
            let type: String?
            let cancellable: Int?
            let userID: Int?
            let title: String?
            let subtitle: String?
            let progress: Int?
            let context: [Context]?

            var isCancellable: Bool {
                return cancellable == 1
            }

            private enum CodingKeys: String, CodingKey {
                case id = "uuid"
                case type, cancellable, userID, title, subtitle, progress
                case context = "Context"
            }

            struct Context: Codable {
                let librarySectionID: String?
            }
        }
    }
}

// MARK: - Plex Sessions Response
struct PlexSessionsResponse: Codable {
    let mediaContainer: SessionsContainer

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct SessionsContainer: Codable {
        let size: Int
        let video: [VideoSession]?
        let track: [TrackSession]?

        private enum CodingKeys: String, CodingKey {
            case size
            case video = "Video"
            case track = "Track"
        }
    }
}

// MARK: - Video Session
struct VideoSession: Codable, Identifiable {
    let id: String
    let sessionKey: String?
    let title: String?
    let year: Int?
    let duration: Int?
    let viewOffset: Int?
    let user: SessionUser?
    let player: SessionPlayer?
    let transcodeSession: TranscodeSession?

    private enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case sessionKey, title, year, duration, viewOffset
        case user = "User"
        case player = "Player"
        case transcodeSession = "TranscodeSession"
    }
}

// MARK: - Track Session
struct TrackSession: Codable, Identifiable {
    let id: String
    let sessionKey: String?
    let title: String?
    let parentTitle: String?
    let grandparentTitle: String?
    let duration: Int?
    let viewOffset: Int?
    let user: SessionUser?
    let player: SessionPlayer?

    private enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case sessionKey, title, parentTitle, grandparentTitle, duration, viewOffset
        case user = "User"
        case player = "Player"
    }
}

// MARK: - Session User
struct SessionUser: Codable {
    let id: Int
    let title: String
    let thumb: String?
}

// MARK: - Session Player
struct SessionPlayer: Codable {
    let address: String?
    let device: String?
    let platform: String?
    let product: String?
    let state: String?
    let title: String?
    let version: String?
}

// MARK: - Transcode Session
struct TranscodeSession: Codable {
    let key: String?
    let progress: Double?
    let speed: Double?
    let duration: Int?
    let videoDecision: String?
    let audioDecision: String?
    let container: String?
    let videoCodec: String?
    let audioCodec: String?
}

// MARK: - Plex Movie Metadata Response
struct PlexMovieMetadataResponse: Codable {
    let mediaContainer: MovieMetadataContainer

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MovieMetadataContainer: Codable {
        let size: Int
        let video: [MovieMetadata]?

        private enum CodingKeys: String, CodingKey {
            case size
            case video = "Video"
        }
    }
}

// MARK: - Movie Metadata
struct MovieMetadata: Codable, Identifiable {
    let id: String
    let title: String?
    let year: Int?
    let studio: String?
    let summary: String?
    let rating: Double?
    let audienceRating: Double?
    let audienceRatingImage: String?
    let contentRating: String?
    let duration: Int?
    let tagline: String?
    let thumb: String?
    let art: String?
    let originallyAvailableAt: String?

    // Cast and Crew
    let roles: [MovieRole]?
    let directors: [MovieDirector]?
    let writers: [MovieWriter]?
    let genres: [MovieGenre]?
    let countries: [MovieCountry]?
    let ratings: [MovieRating]?
    let ultraBlurColors: UltraBlurColors?

    private enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case title, year, studio, summary, rating, audienceRating, audienceRatingImage, contentRating, duration, tagline, thumb, art, originallyAvailableAt
        case roles = "Role"
        case directors = "Director"
        case writers = "Writer"
        case genres = "Genre"
        case countries = "Country"
        case ratings = "Rating"
        case ultraBlurColors = "UltraBlurColors"
    }
}

// MARK: - Movie Role (Cast)
struct MovieRole: Codable, Identifiable {
    let id: String
    let tag: String // Actor name
    let role: String? // Character name
    let thumb: String? // Actor photo

    private enum CodingKeys: String, CodingKey {
        case id
        case tag, role, thumb
    }
}

// MARK: - Movie Director
struct MovieDirector: Codable, Identifiable {
    let id: String
    let tag: String // Director name
    let thumb: String? // Director photo

    private enum CodingKeys: String, CodingKey {
        case id
        case tag, thumb
    }
}

// MARK: - Movie Writer
struct MovieWriter: Codable, Identifiable {
    let id: String
    let tag: String // Writer name
    let thumb: String? // Writer photo

    private enum CodingKeys: String, CodingKey {
        case id
        case tag, thumb
    }
}

// MARK: - Movie Genre
struct MovieGenre: Codable, Identifiable {
    let id: String
    let tag: String // Genre name

    private enum CodingKeys: String, CodingKey {
        case id
        case tag
    }
}

// MARK: - Movie Country
struct MovieCountry: Codable, Identifiable {
    let id: String
    let tag: String // Country name

    private enum CodingKeys: String, CodingKey {
        case id
        case tag
    }
}

// MARK: - Movie Rating
struct MovieRating: Codable, Identifiable {
    let id: String?
    let image: String?
    let type: String?
    let value: Double?
    let count: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case image, type, value, count
    }
}

// MARK: - Ultra Blur Colors
struct UltraBlurColors: Codable {
    let bottomLeft: String?
    let bottomRight: String?
    let topLeft: String?
    let topRight: String?
}

// MARK: - Plex Error Response
struct PlexErrorResponse: Codable {
    let errors: [PlexError]

    struct PlexError: Codable {
        let code: Int
        let message: String
        let status: Int
    }
}

// MARK: - TMDB Models

// TMDB Person Search Response
struct TMDBPersonSearchResponse: Codable {
    let page: Int
    let results: [TMDBPersonSearchResult]
    let totalPages: Int
    let totalResults: Int
    
    private enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBPersonSearchResult: Codable, Identifiable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double
    let knownFor: [TMDBKnownForMovie]?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, popularity
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
        case knownFor = "known_for"
    }
}

struct TMDBKnownForMovie: Codable, Identifiable {
    let id: Int
    let title: String?
    let name: String? // For TV shows
    let releaseDate: String?
    let firstAirDate: String? // For TV shows
    let posterPath: String?
    let mediaType: String
    
    private enum CodingKeys: String, CodingKey {
        case id, title, name
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case mediaType = "media_type"
    }
    
    var displayTitle: String {
        return title ?? name ?? "Unknown Title"
    }
    
    var displayDate: String? {
        return releaseDate ?? firstAirDate
    }
}

// TMDB Person Details Response
struct TMDBPersonDetails: Codable, Identifiable {
    let id: Int
    let name: String
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double
    let homepage: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, biography, birthday, deathday, popularity, homepage
        case placeOfBirth = "place_of_birth"
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}

// TMDB Person Movie Credits Response
struct TMDBPersonMovieCredits: Codable {
    let cast: [TMDBMovieCredit]
    let crew: [TMDBMovieCredit]
}

struct TMDBMovieCredit: Codable, Identifiable {
    let id: Int
    let title: String
    let character: String?
    let job: String?
    let releaseDate: String?
    let posterPath: String?
    let voteAverage: Double
    let popularity: Double
    
    private enum CodingKeys: String, CodingKey {
        case id, title, character, job, popularity
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
    }
}

// MARK: - TMDB Movie Search Models
struct TMDBMovieSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovieSearchResult]
    let totalPages: Int
    let totalResults: Int
    
    private enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBMovieSearchResult: Codable, Identifiable {
    let id: Int
    let title: String
    let releaseDate: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let popularity: Double
    
    private enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
    }
}

// MARK: - Wyzie Subtitle Models
struct WyzieSubtitleResponse: Codable {
    let id: String
    let url: String
    let flagUrl: String
    let format: String
    let encoding: String
    let display: String
    let language: String
    let media: String
    let isHearingImpaired: Bool
    let source: String
}
