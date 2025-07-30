//
//  MainView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

// Persistent storage to prevent actor name loss during state refreshes
class ActorNameStore: ObservableObject {
    @Published var storedActorName: String = ""
}

struct MainView: View {
    @ObservedObject var plexService: PlexService
    @State private var selectedSessionIndex = 0
    @State private var movieMetadata: MovieMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isMovieInfoExpanded = false
    @State private var showingActorDetail = false
    @State private var showingPosterDetail = false
    @State private var selectedActorName = ""
    @State private var pendingActorName = "" // Backup for actor name to prevent state loss
    @State private var metadataTask: Task<Void, Never>? // Track current metadata loading task

    // Persistent storage for actor name that survives state refreshes
    @StateObject private var actorNameStore = ActorNameStore()
    @StateObject private var imdbService = IMDbService()

    var body: some View {
        ZStack {
            // Background gradient using ultra blur colors
            if let movie = movieMetadata, let colors = movie.ultraBlurColors {
                createGradientBackground(colors: colors)
                    .ignoresSafeArea()
            } else {
                // Fallback background
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.gray.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView("Loading movie details...")
                            .padding()
                    } else if let errorMessage = errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        content
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            // Fetch sessions data when the app loads, then load movie metadata
            Task {
                await plexService.fetchSessions()
                loadMovieMetadata()
            }
        }
        .refreshable {
            // Clear current metadata and reset selection
            await MainActor.run {
                selectedSessionIndex = 0
                movieMetadata = nil
                isLoading = false
                errorMessage = nil
            }

            // Cancel any pending metadata task before refreshing
            metadataTask?.cancel()

            // Refresh sessions data on pull-to-refresh
            await plexService.fetchSessions()

            // Load metadata for the refreshed sessions
            loadMovieMetadata()
        }
        .onDisappear {
            // Cancel any pending metadata task when view disappears
            metadataTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        let videoSessions = plexService.activeVideoSessions
        if !videoSessions.isEmpty {
            VStack(spacing: 20) {
                // Movie details
                if let movie = movieMetadata {
                    movieDetailsView(movie: movie)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "tv.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No Active Sessions")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Start playing something on your Plex server to see details here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private func movieDetailsView(movie: MovieMetadata) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Movie title - redesigned to be more compact and elegant
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isMovieInfoExpanded.toggle()
                }
            }) {
                HStack {
                    Text(movie.title ?? "Unknown Title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                        .rotationEffect(.degrees(isMovieInfoExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isMovieInfoExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.regularMaterial)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Collapsible movie info section
            if isMovieInfoExpanded {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Movie poster and basic info section
                        HStack(alignment: .top, spacing: 12) {
                            // Movie poster
                            Button(action: {
                                showingPosterDetail = true
                            }) {
                                AsyncImage(url: posterURL(for: movie.thumb)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fit)
                                } placeholder: {
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .aspectRatio(2/3, contentMode: .fit)
                                }
                                .frame(width: 80)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Basic info
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    if let year = movie.year {
                                        Text(String(year))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    if let contentRating = movie.contentRating {
                                        Text(contentRating)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(3)
                                    }
                                }

                                if let duration = movie.duration {
                                    Text(formatTime(duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                // Ratings section
                                if let ratings = movie.ratings, !ratings.isEmpty {
                                    ratingsView(ratings: ratings)
                                        .onAppear {
                                            print("🎭 MainView: Displaying \(ratings.count) ratings")
                                            for (index, rating) in ratings.enumerated() {
                                                print("   Rating \(index): type=\(rating.type ?? "nil"), value=\(rating.value ?? -1), image=\(rating.image ?? "nil")")
                                            }
                                        }
                                } else {
                                    Text("No ratings available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .onAppear {
                                            print("🎭 MainView: No ratings to display - ratings: \(movie.ratings?.count ?? 0)")
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Summary
                        if let summary = movie.summary {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(summary)
                                    .font(.body)
                                    .lineLimit(nil)
                            }
                        }

                        // Genres
                        if let genres = movie.genres, !genres.isEmpty {
                            genrePillsView(genres: genres)
                        }

                        // Countries
                        if let countries = movie.countries, !countries.isEmpty {
                            countriesView(countries: countries)
                        }

                        // Directors
                        if let directors = movie.directors, !directors.isEmpty {
                            directorsView(directors: directors)
                        }

                        // Writers
                        if let writers = movie.writers, !writers.isEmpty {
                            writersView(writers: writers)
                        }
                    }
                }
                .padding()
                .background(.thickMaterial)
                .cornerRadius(12)
            }

            // Cast section - always visible with refined spacing
            if let roles = movie.roles, !roles.isEmpty {
                castView(cast: roles)
            }
        }
    }

    private func ratingsView(ratings: [MovieRating]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ratings")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 6) {
                // First row: Rotten Tomatoes (critic and audience)
                HStack(spacing: 8) {
                    ForEach(ratings.filter { $0.image?.contains("rottentomatoes") == true }, id: \.computedId) { rating in
                        HStack(spacing: 4) {
                            if rating.type == "critic" {
                                // Tomato with color based on Fresh (≥6.0) vs Rotten (<6.0)
                                let isFresh = (rating.value ?? 0) >= 6.0
                                Text("🍅")
                                    .font(.caption)
                                    .foregroundColor(isFresh ? .red : .green)
                            } else {
                                // Audience rating - keep person icon
                                Image(systemName: "person.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }

                            if let value = rating.value {
                                Text(formatRating(value))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(6)
                    }
                    Spacer()
                }

                // Second row: IMDb and TMDb
                HStack(spacing: 8) {
                    ForEach(ratings.filter { $0.image?.contains("imdb") == true || $0.image?.contains("themoviedb") == true }, id: \.computedId) { rating in
                        HStack(spacing: 4) {
                            if let image = rating.image {
                                if image.contains("imdb") {
                                    Text("IMDb")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.yellow)
                                } else if image.contains("themoviedb") {
                                    Text("TMDb")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }

                            if let value = rating.value {
                                Text(formatRating(value))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(6)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            print("DEBUG - Movie ratings count: \(ratings.count)")
            for (index, rating) in ratings.enumerated() {
                print("DEBUG - Rating \(index): image=\(rating.image ?? "nil"), value=\(rating.value?.description ?? "nil"), type=\(rating.type ?? "nil"), id=\(rating.id ?? "nil")")
            }
        }
    }

    private func genrePillsView(genres: [MovieGenre]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genres")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(genres) { genre in
                    Text(genre.tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }
            }
        }
    }

    private func countriesView(countries: [MovieCountry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Countries")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(countries) { country in
                    Text(country.tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(16)
                }
            }
        }
    }

    private func directorsView(directors: [MovieDirector]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directors")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(directors) { director in
                    HStack {
                        AsyncImage(url: thumbnailURL(for: director.thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.title2)
                            case .empty:
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.title2)
                            @unknown default:
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.title2)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .background(Circle().fill(Color.gray.opacity(0.1)))

                        Text(director.tag)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func writersView(writers: [MovieWriter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writers")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(writers) { writer in
                    HStack {
                        AsyncImage(url: thumbnailURL(for: writer.thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.title2)
                            case .empty:
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.title2)
                            @unknown default:
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.title2)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .background(Circle().fill(Color.gray.opacity(0.1)))

                        Text(writer.tag)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func castView(cast: [MovieRole]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 12) {
                ForEach(cast) { role in
                    Button(action: {
                        print("🎬 MainView: User tapped actor button")
                        print("   Role ID: '\(role.id)'")
                        print("   Role Tag (Actor Name): '\(role.tag)'")
                        print("   Role Role (Character): '\(role.role ?? "N/A")'")

                        // Store in persistent store first
                        actorNameStore.storedActorName = role.tag

                        // Set both backup and primary actor name to prevent state loss during polling
                        pendingActorName = role.tag
                        selectedActorName = role.tag
                        showingActorDetail = true

                        print("   pendingActorName set to: '\(pendingActorName)'")
                        print("   selectedActorName set to: '\(selectedActorName)'")
                        print("   storedActorName set to: '\(actorNameStore.storedActorName)'")
                        print("   showingActorDetail set to: \(showingActorDetail)")
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: thumbnailURL(for: role.thumb)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure(_):
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray.opacity(0.6))
                                                .font(.system(size: 32))
                                        )
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray.opacity(0.6))
                                                .font(.system(size: 32))
                                        )
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray.opacity(0.6))
                                                .font(.system(size: 32))
                                        )
                                }
                            }
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.tag)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                if let character = role.role {
                                    Text(character)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.thickMaterial)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showingActorDetail, onDismiss: {
            print("🎭 MainView: Sheet dismissed, clearing actor names")
            selectedActorName = ""
            pendingActorName = ""
            actorNameStore.storedActorName = ""
        }) {
            ActorDetailView(
                actorName: {
                    // Use primary state first, then backup, then persistent store
                    let actorNameToUse = !selectedActorName.isEmpty ? selectedActorName :
                                        !pendingActorName.isEmpty ? pendingActorName :
                                        actorNameStore.storedActorName
                    print("🎭 MainView: Presenting sheet with actor name: '\(actorNameToUse)'")
                    print("   selectedActorName: '\(selectedActorName)'")
                    print("   pendingActorName: '\(pendingActorName)'")
                    print("   storedActorName: '\(actorNameStore.storedActorName)'")
                    return actorNameToUse
                }(),
                imdbService: imdbService,
                movieYear: movieMetadata?.year,
                movieIMDbID: movieMetadata?.imdbID
            )
        }
        .sheet(isPresented: $showingPosterDetail) {
            if let movie = movieMetadata {
                PosterDetailView(
                    posterURL: posterURL(for: movie.thumb),
                    movieTitle: movie.title ?? "Unknown Title"
                )
            }
        }
    }

    // Helper functions for URLs
    private func artURL(for artPath: String?) -> URL? {
        guard let artPath = artPath else { return nil }

        // If it's already a full URL (like metadata-static.plex.tv), use it directly
        if artPath.hasPrefix("http://") || artPath.hasPrefix("https://") {
            return URL(string: artPath)
        }

        // Otherwise, construct local server URL with auth token
        let urlString = "http://\(plexService.settings.serverIP):32400\(artPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    private func posterURL(for thumbPath: String?) -> URL? {
        guard let thumbPath = thumbPath else { return nil }

        // If it's already a full URL (like metadata-static.plex.tv), use it directly
        if thumbPath.hasPrefix("http://") || thumbPath.hasPrefix("https://") {
            return URL(string: thumbPath)
        }

        // Otherwise, construct local server URL with auth token
        let urlString = "http://\(plexService.settings.serverIP):32400\(thumbPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    private func thumbnailURL(for thumbPath: String?) -> URL? {
        guard let thumbPath = thumbPath else { return nil }

        // If it's already a full URL (like metadata-static.plex.tv), use it directly
        if thumbPath.hasPrefix("http://") || thumbPath.hasPrefix("https://") {
            return URL(string: thumbPath)
        }

        // Otherwise, construct local server URL with auth token
        let urlString = "http://\(plexService.settings.serverIP):32400\(thumbPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    private func formatTime(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func loadMovieMetadata() {
        let videoSessions = plexService.activeVideoSessions
        guard selectedSessionIndex < videoSessions.count else {
            print("⚠️ MainView: selectedSessionIndex \(selectedSessionIndex) is out of bounds for \(videoSessions.count) sessions")
            return
        }

        let currentSession = videoSessions[selectedSessionIndex]
        print("🎬 MainView: Loading metadata for session \(selectedSessionIndex): \(currentSession.title ?? "Unknown")")

        // Cancel any existing metadata loading task
        metadataTask?.cancel()

        isLoading = true
        errorMessage = nil

        metadataTask = Task {
            do {
                let response = try await plexService.getMovieMetadata(ratingKey: currentSession.id)

                // Check if task was cancelled
                if Task.isCancelled {
                    print("🔄 MainView: Metadata loading task was cancelled")
                    return
                }

                await MainActor.run {
                    self.movieMetadata = response.mediaContainer.video?.first
                    if let movie = self.movieMetadata {
                        print("🎬 Movie loaded: \(movie.title ?? "Unknown")")
                        if movie.ultraBlurColors != nil {
                            print("🎨 UltraBlurColors found!")
                        } else {
                            print("❌ No UltraBlurColors in movie data")
                        }
                    }
                    self.isLoading = false
                }

            } catch {
                // Don't show errors for cancelled tasks
                if !Task.isCancelled {
                    await MainActor.run {
                        print("❌ MainView: Error loading movie metadata: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                } else {
                    print("🔄 MainView: Metadata loading was cancelled")
                }
            }
        }
    }

     private func createGradientBackground(colors: UltraBlurColors) -> some View {
        print("🎨 Ultra Blur Colors received:")
        print("  topLeft: \(colors.topLeft ?? "nil")")
        print("  topRight: \(colors.topRight ?? "nil")")
        print("  bottomLeft: \(colors.bottomLeft ?? "nil")")
        print("  bottomRight: \(colors.bottomRight ?? "nil")")

        let topLeft = Color(hex: colors.topLeft ?? "000000")
        let topRight = Color(hex: colors.topRight ?? "000000")
        let bottomLeft = Color(hex: colors.bottomLeft ?? "000000")
        let bottomRight = Color(hex: colors.bottomRight ?? "000000")

        return LinearGradient(
            colors: [
                topLeft.opacity(0.4),
                topRight.opacity(0.2),
                bottomLeft.opacity(0.2),
                bottomRight.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Helper function to safely format rating values
    private func formatRating(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "N/A"
        }
        return String(format: "%.1f", value)
    }
}

// Color extension to handle hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Flow layout for genre pills
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                    y: bounds.minY + result.frames[index].minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Layout.Subviews, spacing: CGFloat) {
            var currentPosition: CGPoint = .zero
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if currentPosition.x + subviewSize.width > maxWidth && currentPosition.x > 0 {
                    // Move to next row
                    currentPosition.x = 0
                    currentPosition.y += rowHeight + spacing
                    rowHeight = 0
                }

                frames.append(CGRect(origin: currentPosition, size: subviewSize))

                currentPosition.x += subviewSize.width + spacing
                rowHeight = max(rowHeight, subviewSize.height)
            }

            size = CGSize(width: maxWidth, height: currentPosition.y + rowHeight)
        }
    }
}

// Poster detail view for expanded poster display
struct PosterDetailView: View {
    let posterURL: URL?
    let movieTitle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Spacer()

                        AsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.3))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.5)
                                )
                        }
                        .frame(maxWidth: min(geometry.size.width * 0.9, geometry.size.height * 0.6))
                        .cornerRadius(12)
                        .shadow(radius: 10)

                        Spacer()
                    }
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(movieTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MainView(plexService: PlexService())
}
