//
//  PlexService.swift
//  They Were Also In This
//
//  Created by Eric on 7/28/25.
//

import Foundation
import Combine

@MainActor
class PlexService: ObservableObject {
    @Published var settings = PlexSettings()
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var serverCapabilities: PlexCapabilitiesResponse?
    @Published var activities: PlexActivitiesResponse?
    @Published var sessions: PlexSessionsResponse?

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "PlexSettings"

    init() {
        loadSettings()
        checkTokenValidity()
    }

    // MARK: - Settings Management
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(PlexSettings.self, from: data) {
            self.settings = settings
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    func updateServerIP(_ ip: String) {
        settings.serverIP = ip
        saveSettings()
    }

    // MARK: - Authentication
    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await authenticateWithPlex(username: username, password: password)
            settings.plexToken = token
            settings.tokenExpirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) // Assume 30-day validity
            saveSettings()
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func authenticateWithPlex(username: String, password: String) async throws -> String {
        guard let url = URL(string: "https://plex.tv/users/sign_in.json") else {
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("They Were Also In This iOS App", forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("They Were Also In This", forHTTPHeaderField: "X-Plex-Product")
        request.setValue("1.0", forHTTPHeaderField: "X-Plex-Version")
        request.setValue("iOS", forHTTPHeaderField: "X-Plex-Platform")
        request.setValue("18.5", forHTTPHeaderField: "X-Plex-Platform-Version")
        request.setValue("mobile", forHTTPHeaderField: "X-Plex-Device")

        // Create the correct JSON payload format for Plex
        let loginPayload = [
            "user": [
                "login": username,
                "password": password
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: loginPayload, options: [])
            request.httpBody = jsonData

            print("🔐 Attempting Plex authentication...")
            print("📍 URL: \(url)")
            print("📦 Payload: \(String(data: jsonData, encoding: .utf8) ?? "nil")")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw PlexError.invalidResponse
            }

            print("📊 Response status: \(httpResponse.statusCode)")
            print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            if httpResponse.statusCode == 401 {
                throw PlexError.invalidCredentials
            }

            if httpResponse.statusCode == 422 {
                // Handle validation errors
                if let errorResponse = try? JSONDecoder().decode(PlexErrorResponse.self, from: data) {
                    let errorMessage = errorResponse.errors.map { $0.message }.joined(separator: ", ")
                    throw PlexError.validationError(errorMessage)
                }
                throw PlexError.invalidCredentials
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                throw PlexError.serverError(httpResponse.statusCode)
            }

            let authResponse = try JSONDecoder().decode(PlexAuthResponse.self, from: data)
            print("✅ Authentication successful, token received")
            return authResponse.user.authToken

        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw PlexError.invalidResponse
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }

    func checkTokenValidity() {
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            isLoggedIn = false
            return
        }

        // If we have both IP and token, consider logged in
        isLoggedIn = true

        // Then verify the token works by calling server capabilities
        Task {
            do {
                _ = try await getServerCapabilities()
                // Token is valid, keep logged in status
            } catch {
                // Token is invalid, log out
                await MainActor.run {
                    isLoggedIn = false
                    settings.plexToken = ""
                    settings.tokenExpirationDate = nil
                    saveSettings()
                }
            }
        }
    }

    func logout() {
        settings.plexToken = ""
        settings.tokenExpirationDate = nil
        saveSettings()
        isLoggedIn = false
        serverCapabilities = nil
        activities = nil
        sessions = nil
    }

    // MARK: - Server Capabilities
    func getServerCapabilities() async throws -> PlexCapabilitiesResponse {
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        let urlString = "http://\(settings.serverIP):32400/?X-Plex-Token=\(settings.plexToken)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // 10 second timeout

        print("🏠 Checking server capabilities...")
        print("📍 URL: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw PlexError.invalidResponse
            }

            print("📊 Server response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                print("❌ Server returned 401 - Token invalid or expired")
                throw PlexError.invalidToken
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Server error: \(httpResponse.statusCode)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw PlexError.serverError(httpResponse.statusCode)
            }

            print("✅ Server capabilities received successfully")
            print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            let capabilities = try JSONDecoder().decode(PlexCapabilitiesResponse.self, from: data)
            await MainActor.run {
                self.serverCapabilities = capabilities
            }
            return capabilities

        } catch let error as PlexError {
            throw error
        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw PlexError.invalidResponse
        } catch {
            print("❌ Network error: \(error)")
            throw PlexError.invalidResponse
        }
    }

    func fetchServerCapabilities() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getServerCapabilities()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Activities
    func getActivities() async throws -> PlexActivitiesResponse {
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        let urlString = "http://\(settings.serverIP):32400/activities/?X-Plex-Token=\(settings.plexToken)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // 10 second timeout

        print("🔄 Fetching server activities...")
        print("📍 URL: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw PlexError.invalidResponse
            }

            print("📊 Activities response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                print("❌ Server returned 401 - Token invalid or expired")
                throw PlexError.invalidToken
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Server error: \(httpResponse.statusCode)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw PlexError.serverError(httpResponse.statusCode)
            }

            print("✅ Activities received successfully")
            print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            let activitiesResponse = try parseActivitiesXML(data: data)
            await MainActor.run {
                self.activities = activitiesResponse
            }
            return activitiesResponse

        } catch let error as PlexError {
            throw error
        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw PlexError.invalidResponse
        } catch {
            print("❌ Network error: \(error)")
            throw PlexError.invalidResponse
        }
    }

    func fetchActivities() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getActivities()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sessions
    func getSessions() async throws -> PlexSessionsResponse {
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        let urlString = "http://\(settings.serverIP):32400/status/sessions?X-Plex-Token=\(settings.plexToken)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw PlexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // 10 second timeout

        print("🎬 Fetching server sessions...")
        print("📍 URL: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw PlexError.invalidResponse
            }

            print("📊 Sessions response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                print("❌ Server returned 401 - Token invalid or expired")
                throw PlexError.invalidToken
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Server error: \(httpResponse.statusCode)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw PlexError.serverError(httpResponse.statusCode)
            }

            print("✅ Sessions received successfully")
            print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            let sessionsResponse = try parseSessionsXML(data: data)
            await MainActor.run {
                self.sessions = sessionsResponse
            }
            return sessionsResponse

        } catch let error as PlexError {
            throw error
        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw PlexError.invalidResponse
        } catch {
            print("❌ Network error: \(error)")
            throw PlexError.invalidResponse
        }
    }

    func fetchSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getSessions()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - XML Parsing
    private func parseActivitiesXML(data: Data) throws -> PlexActivitiesResponse {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("❌ Unable to convert data to string")
            throw PlexError.invalidResponse
        }

        print("🔍 Parsing XML: \(xmlString)")

        let parser = XMLParser(data: data)
        let delegate = ActivitiesXMLParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            if let response = delegate.activitiesResponse {
                return response
            } else {
                print("❌ No activities response parsed")
                throw PlexError.invalidResponse
            }
        } else {
            print("❌ XML parsing failed")
            throw PlexError.invalidResponse
        }
    }

    private func parseSessionsXML(data: Data) throws -> PlexSessionsResponse {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("❌ Unable to convert data to string")
            throw PlexError.invalidResponse
        }

        print("🔍 Parsing Sessions XML: \(xmlString)")

        let parser = XMLParser(data: data)
        let delegate = SessionsXMLParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            if let response = delegate.sessionsResponse {
                return response
            } else {
                print("❌ No sessions response parsed")
                throw PlexError.invalidResponse
            }
        } else {
            print("❌ Sessions XML parsing failed")
            throw PlexError.invalidResponse
        }
    }
}

// MARK: - XML Parser Delegate for Activities
class ActivitiesXMLParserDelegate: NSObject, XMLParserDelegate {
    var activitiesResponse: PlexActivitiesResponse?
    var currentActivity: PlexActivitiesResponse.ActivitiesContainer.Activity?
    var currentContext: PlexActivitiesResponse.ActivitiesContainer.Activity.Context?
    var activities: [PlexActivitiesResponse.ActivitiesContainer.Activity] = []
    var contexts: [PlexActivitiesResponse.ActivitiesContainer.Activity.Context] = []
    var containerSize: Int = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "MediaContainer":
            containerSize = Int(attributeDict["size"] ?? "0") ?? 0

        case "Activity":
            let id = attributeDict["uuid"] ?? ""
            let type = attributeDict["type"]
            let cancellable = Int(attributeDict["cancellable"] ?? "0")
            let userID = Int(attributeDict["userID"] ?? "0")
            let title = attributeDict["title"]
            let subtitle = attributeDict["subtitle"]
            let progress = Int(attributeDict["progress"] ?? "0")

            currentActivity = PlexActivitiesResponse.ActivitiesContainer.Activity(
                id: id,
                type: type,
                cancellable: cancellable,
                userID: userID,
                title: title,
                subtitle: subtitle,
                progress: progress,
                context: nil // Will be set later
            )
            contexts = [] // Reset contexts for this activity

        case "Context":
            let librarySectionID = attributeDict["librarySectionID"]
            let context = PlexActivitiesResponse.ActivitiesContainer.Activity.Context(
                librarySectionID: librarySectionID
            )
            contexts.append(context)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Activity":
            if var activity = currentActivity {
                // Set contexts if we have any
                if !contexts.isEmpty {
                    activity = PlexActivitiesResponse.ActivitiesContainer.Activity(
                        id: activity.id,
                        type: activity.type,
                        cancellable: activity.cancellable,
                        userID: activity.userID,
                        title: activity.title,
                        subtitle: activity.subtitle,
                        progress: activity.progress,
                        context: contexts
                    )
                }
                activities.append(activity)
            }
            currentActivity = nil

        case "MediaContainer":
            let container = PlexActivitiesResponse.ActivitiesContainer(
                size: containerSize,
                activity: activities.isEmpty ? nil : activities
            )
            activitiesResponse = PlexActivitiesResponse(mediaContainer: container)

        default:
            break
        }
    }
}

// MARK: - XML Parser Delegate for Sessions
class SessionsXMLParserDelegate: NSObject, XMLParserDelegate {
    var sessionsResponse: PlexSessionsResponse?
    var containerSize: Int = 0
    var videoSessions: [VideoSession] = []
    var trackSessions: [TrackSession] = []

    // Current session being parsed
    var currentVideoSession: VideoSession?
    var currentTrackSession: TrackSession?
    var currentUser: SessionUser?
    var currentPlayer: SessionPlayer?
    var currentTranscodeSession: TranscodeSession?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "MediaContainer":
            containerSize = Int(attributeDict["size"] ?? "0") ?? 0

        case "Video":
            let id = attributeDict["ratingKey"] ?? ""
            let sessionKey = attributeDict["sessionKey"]
            let title = attributeDict["title"]
            let year = Int(attributeDict["year"] ?? "0")
            let duration = Int(attributeDict["duration"] ?? "0")
            let viewOffset = Int(attributeDict["viewOffset"] ?? "0")

            currentVideoSession = VideoSession(
                id: id,
                sessionKey: sessionKey,
                title: title,
                year: year,
                duration: duration,
                viewOffset: viewOffset,
                user: nil,
                player: nil,
                transcodeSession: nil
            )

        case "Track":
            let id = attributeDict["ratingKey"] ?? ""
            let sessionKey = attributeDict["sessionKey"]
            let title = attributeDict["title"]
            let parentTitle = attributeDict["parentTitle"]
            let grandparentTitle = attributeDict["grandparentTitle"]
            let duration = Int(attributeDict["duration"] ?? "0")
            let viewOffset = Int(attributeDict["viewOffset"] ?? "0")

            currentTrackSession = TrackSession(
                id: id,
                sessionKey: sessionKey,
                title: title,
                parentTitle: parentTitle,
                grandparentTitle: grandparentTitle,
                duration: duration,
                viewOffset: viewOffset,
                user: nil,
                player: nil
            )

        case "User":
            let id = Int(attributeDict["id"] ?? "0") ?? 0
            let title = attributeDict["title"] ?? ""
            let thumb = attributeDict["thumb"]

            currentUser = SessionUser(id: id, title: title, thumb: thumb)

        case "Player":
            let address = attributeDict["address"]
            let device = attributeDict["device"]
            let platform = attributeDict["platform"]
            let product = attributeDict["product"]
            let state = attributeDict["state"]
            let title = attributeDict["title"]
            let version = attributeDict["version"]

            currentPlayer = SessionPlayer(
                address: address,
                device: device,
                platform: platform,
                product: product,
                state: state,
                title: title,
                version: version
            )

        case "TranscodeSession":
            let key = attributeDict["key"]
            let progress = Double(attributeDict["progress"] ?? "0")
            let speed = Double(attributeDict["speed"] ?? "0")
            let duration = Int(attributeDict["duration"] ?? "0")
            let videoDecision = attributeDict["videoDecision"]
            let audioDecision = attributeDict["audioDecision"]
            let container = attributeDict["container"]
            let videoCodec = attributeDict["videoCodec"]
            let audioCodec = attributeDict["audioCodec"]

            currentTranscodeSession = TranscodeSession(
                key: key,
                progress: progress,
                speed: speed,
                duration: duration,
                videoDecision: videoDecision,
                audioDecision: audioDecision,
                container: container,
                videoCodec: videoCodec,
                audioCodec: audioCodec
            )

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Video":
            if var session = currentVideoSession {
                // Update session with user, player, and transcode info
                session = VideoSession(
                    id: session.id,
                    sessionKey: session.sessionKey,
                    title: session.title,
                    year: session.year,
                    duration: session.duration,
                    viewOffset: session.viewOffset,
                    user: currentUser,
                    player: currentPlayer,
                    transcodeSession: currentTranscodeSession
                )
                videoSessions.append(session)
            }
            currentVideoSession = nil
            currentUser = nil
            currentPlayer = nil
            currentTranscodeSession = nil

        case "Track":
            if var session = currentTrackSession {
                session = TrackSession(
                    id: session.id,
                    sessionKey: session.sessionKey,
                    title: session.title,
                    parentTitle: session.parentTitle,
                    grandparentTitle: session.grandparentTitle,
                    duration: session.duration,
                    viewOffset: session.viewOffset,
                    user: currentUser,
                    player: currentPlayer
                )
                trackSessions.append(session)
            }
            currentTrackSession = nil
            currentUser = nil
            currentPlayer = nil

        case "MediaContainer":
            let container = PlexSessionsResponse.SessionsContainer(
                size: containerSize,
                video: videoSessions.isEmpty ? nil : videoSessions,
                track: trackSessions.isEmpty ? nil : trackSessions
            )
            sessionsResponse = PlexSessionsResponse(mediaContainer: container)

        default:
            break
        }
    }
}

// MARK: - Plex Errors
enum PlexError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCredentials
    case invalidToken
    case notAuthenticated
    case validationError(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidCredentials:
            return "Invalid username or password"
        case .invalidToken:
            return "Invalid or expired token"
        case .notAuthenticated:
            return "Not authenticated. Please log in first."
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}