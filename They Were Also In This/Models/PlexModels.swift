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

// MARK: - Plex Error Response
struct PlexErrorResponse: Codable {
    let errors: [PlexError]

    struct PlexError: Codable {
        let code: Int
        let message: String
        let status: Int
    }
}
