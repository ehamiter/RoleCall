//
//  PlexModels.swift
//  They Were Also In This
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

// MARK: - Plex Error Response
struct PlexErrorResponse: Codable {
    let errors: [PlexError]

    struct PlexError: Codable {
        let code: Int
        let message: String
        let status: Int
    }
}
