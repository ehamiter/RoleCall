import Foundation

// MARK: - Subtitle Models
struct SubtitleEntry {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

struct ActorLine {
    let start: TimeInterval
    let end: TimeInterval
    let character: String
    let actor: String?
    let line: String
}

class SubtitleService {
    
    // MARK: - SRT Parsing
    func parseSRT(_ srt: String) -> [SubtitleEntry] {
        let regex = try! NSRegularExpression(
            pattern: #"(\d+)\s+(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})\s+([\s\S]*?)(?=\n\d+\n|\z)"#
        )
        
        let nsrange = NSRange(srt.startIndex..<srt.endIndex, in: srt)
        let matches = regex.matches(in: srt, range: nsrange)
        
        return matches.map { match in
            func time(_ idx: Int) -> TimeInterval {
                let h = Double(Int((srt as NSString).substring(with: match.range(at: idx)))!)
                let m = Double(Int((srt as NSString).substring(with: match.range(at: idx+1)))!)
                let s = Double(Int((srt as NSString).substring(with: match.range(at: idx+2)))!)
                let ms = Double(Int((srt as NSString).substring(with: match.range(at: idx+3)))!)
                return h * 3600 + m * 60 + s + ms / 1000.0
            }
            let start = time(2)
            let end = time(6)
            let text = (srt as NSString).substring(with: match.range(at: 10)).trimmingCharacters(in: .whitespacesAndNewlines)
            return SubtitleEntry(start: start, end: end, text: text)
        }
    }
    
    // MARK: - Wyzie Subtitle API
    func downloadWyzieSubtitles(tmdbId: Int) async throws -> String {
        let searchURL = "https://sub.wyzie.ru/search?id=\(tmdbId)"
        
        guard let url = URL(string: searchURL) else {
            throw SubtitleError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        print("🔍 Searching Wyzie subtitles for TMDB ID: \(tmdbId)")
        print("📍 URL: \(searchURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubtitleError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw SubtitleError.httpError(httpResponse.statusCode)
            }
            
            let subtitles = try JSONDecoder().decode([WyzieSubtitleResponse].self, from: data)
            
            // Find the first English subtitle
            guard let englishSubtitle = subtitles.first(where: { $0.language == "en" && $0.format == "srt" }) else {
                throw SubtitleError.noEnglishSubtitles
            }
            
            print("✅ Found English subtitle: \(englishSubtitle.display)")
            
            // Download the actual SRT content
            return try await downloadSRTFromURL(englishSubtitle.url)
            
        } catch let error as SubtitleError {
            throw error
        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding error: \(decodingError)")
            throw SubtitleError.decodingError
        } catch {
            print("❌ Network error: \(error)")
            throw SubtitleError.networkError
        }
    }
    
    private func downloadSRTFromURL(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw SubtitleError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        print("📥 Downloading SRT from: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubtitleError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw SubtitleError.httpError(httpResponse.statusCode)
            }
            
            guard let srtContent = String(data: data, encoding: .utf8), !srtContent.isEmpty else {
                throw SubtitleError.emptyContent
            }
            
            print("✅ SRT downloaded successfully from Wyzie")
            return srtContent
            
        } catch let error as SubtitleError {
            throw error
        } catch {
            print("❌ Network error downloading SRT: \(error)")
            throw SubtitleError.networkError
        }
    }
    
    // MARK: - Character to Actor Mapping
    func mapCharactersToActors(cast: [(character: String, actor: String)], srtEntries: [SubtitleEntry]) -> [ActorLine] {
        // Create character mapping with better duplicate handling
        var charMap: [String: String] = [:]
        var characterNamesToSearch: [String] = []
        
        // First, try exact matches (full character names)
        for (character, actor) in cast {
            let upperCharacter = character.uppercased()
            charMap[upperCharacter] = actor
            characterNamesToSearch.append(upperCharacter)
        }
        
        // Then, add first-word matches (but don't overwrite exact matches)
        for (character, actor) in cast {
            let firstWord = String(character.split(separator: " ")[0]).uppercased()
            if charMap[firstWord] == nil {
                charMap[firstWord] = actor
                characterNamesToSearch.append(firstWord)
            }
        }
        
        // Sort character names by length (longest first) to match longer names before shorter ones
        characterNamesToSearch.sort { $0.count > $1.count }
        
        var mapped: [ActorLine] = []
        
        // Search each subtitle entry for character names mentioned in the text
        for entry in srtEntries {
            let upperText = entry.text.uppercased()
            
            // Find all character names mentioned in this subtitle entry
            var charactersInEntry: Set<String> = []
            
            for characterName in characterNamesToSearch {
                // Use word boundary matching to avoid partial matches
                // Look for the character name as a whole word
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: characterName))\\b"
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(upperText.startIndex..., in: upperText)
                    if regex.firstMatch(in: upperText, options: [], range: range) != nil {
                        charactersInEntry.insert(characterName)
                    }
                }
            }
            
            // Create an ActorLine for each character found in this subtitle entry
            for characterName in charactersInEntry {
                if let actor = charMap[characterName] {
                    // Convert back to original case for display
                    let originalCharacterName = cast.first { $0.character.uppercased() == characterName || String($0.character.split(separator: " ")[0]).uppercased() == characterName }?.character ?? characterName
                    
                    mapped.append(ActorLine(
                        start: entry.start,
                        end: entry.end,
                        character: originalCharacterName,
                        actor: actor,
                        line: entry.text
                    ))
                }
            }
        }
        
        return mapped
    }
    
    // MARK: - Scene Analysis
    func actorsInScene(at timestamp: TimeInterval, mapped: [ActorLine]) -> [(String, String?)] {
        return mapped.filter { $0.start <= timestamp && timestamp <= $0.end }
                     .map { ($0.character, $0.actor) }
    }
    
    // MARK: - Helper Functions
    func convertMillisecondsToTimeInterval(_ milliseconds: Int) -> TimeInterval {
        return TimeInterval(milliseconds) / 1000.0
    }
    
    func createCastMapping(from roles: [MovieRole]) -> [(character: String, actor: String)] {
        return roles.compactMap { role in
            guard let character = role.role else { return nil }
            return (character: character, actor: role.tag)
        }
    }
}

// MARK: - Subtitle Errors
enum SubtitleError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case httpError(Int)
    case noEnglishSubtitles
    case emptyContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid subtitle URL"
        case .invalidResponse:
            return "Invalid response from subtitle service"
        case .networkError:
            return "Network error while downloading subtitles"
        case .decodingError:
            return "Failed to decode subtitle response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noEnglishSubtitles:
            return "No English subtitles found"
        case .emptyContent:
            return "Downloaded subtitle content is empty"
        }
    }
}