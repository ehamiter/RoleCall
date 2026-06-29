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
                .padding(.top, 2)
            }
            .refreshable {
                await refreshSessions()
            }
        }
        .onAppear {
            // Fetch sessions data when the app loads, then load movie metadata
            Task {
                await plexService.fetchSessions()
                loadMovieMetadata()
            }
        }

        .onDisappear {
            // Cancel any pending metadata task when view disappears
            metadataTask?.cancel()
        }
        .onChange(of: plexService.selectedSessionIndex) { newValue in
            // Reload movie metadata when session selection changes
            print("🔄 MainView: Session selection changed to \(newValue)")
            loadMovieMetadata()
        }
    }
    
    private func refreshSessions() async {
        print("🔄 MainView: Pull-to-refresh triggered")
        
        // Store the current session information before refresh
        let videoSessionsBeforeRefresh = plexService.activeVideoSessions
        let currentSessionIndex = plexService.selectedSessionIndex
        
        // Always fetch fresh session data
        await plexService.fetchSessions()
        
        // Get updated session information
        let videoSessionsAfterRefresh = plexService.activeVideoSessions
        
        print("🔄 MainView: Sessions before refresh: \(videoSessionsBeforeRefresh.count)")
        print("🔄 MainView: Sessions after refresh: \(videoSessionsAfterRefresh.count)")
        print("🔄 MainView: Current selected index: \(currentSessionIndex)")
        
        // Handle session selection based on the new requirements
        if videoSessionsAfterRefresh.isEmpty {
            // No sessions: Reset to default and show "nothing playing"
            print("🔄 MainView: No active sessions - showing 'nothing playing' page")
            plexService.selectedSessionIndex = 0
            // Clear current movie metadata since there's nothing playing
            movieMetadata = nil
        } else if videoSessionsAfterRefresh.count == 1 {
            // Single session: Keep showing that session (set index to 0)
            print("🔄 MainView: Single session - keeping current display")
            plexService.selectedSessionIndex = 0
            // Reload metadata for the single session
            loadMovieMetadata()
        } else {
            // Multiple sessions: Preserve current selection if it's still valid
            if currentSessionIndex < videoSessionsAfterRefresh.count {
                print("🔄 MainView: Multiple sessions - preserving current selection (index \(currentSessionIndex))")
                // Keep the current selection and reload its metadata
                loadMovieMetadata()
            } else {
                print("🔄 MainView: Current selection out of bounds - resetting to first session")
                // Current selection is out of bounds, reset to first session
                plexService.selectedSessionIndex = 0
                loadMovieMetadata()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let videoSessions = plexService.activeVideoSessions
        if !videoSessions.isEmpty {
            VStack(spacing: 8) {
                // Movie details
                if let movie = movieMetadata {
                    movieDetailsView(movie: movie)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
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
        VStack(alignment: .leading, spacing: 40) {
            // Movie title - redesigned to be more compact and elegant
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .onTapGesture {
                        print("🎬 MainView: Movie title tapped")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMovieInfoExpanded.toggle()
                        }
                        print("🎬 MainView: isMovieInfoExpanded is now: \(isMovieInfoExpanded)")
                    }
                
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
                .padding(.vertical, 16)
                .allowsHitTesting(false)
            }
            .padding(.bottom, 20)

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

                            // ✦ Info column beside the poster: metadata line + rating chips
                            //   that wrap to fill the space next to the poster.
                            VStack(alignment: .leading, spacing: 10) {
                                // ✦ Consolidated metadata line: "year · runtime" + certification pill
                                HStack(spacing: 8) {
                                    let meta = [movie.year.map { String($0) }, movie.duration.map { formatTime($0) }]
                                        .compactMap { $0 }
                                    if !meta.isEmpty {
                                        Text(meta.joined(separator: "  ·  ")) // ✦ native TV-app style separator
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    if let contentRating = movie.contentRating {
                                        Text(contentRating)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .overlay( // ✦ outlined pill reads clearly as a certification badge
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                }

                                // ✦ Rating chips, beside the poster; wrap to a 2nd line if the column is tight
                                if let ratings = movie.ratings, !ratings.isEmpty {
                                    ratingsView(ratings: ratings, imdbID: movie.imdbID)
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

    // ✦ Shared capsule chip — consistent styling & a comfortable, legible 36pt height for every rating source.
    @ViewBuilder
    private func ratingChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 5) {
            content()
        }
        .font(.subheadline.weight(.semibold)) // ✦ weight folded into Font (iOS 15-safe; the .fontWeight view modifier is iOS 16+)
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .frame(minHeight: 36) // ✦ uniform, easy-to-read chip height
        .background(Color(.tertiarySystemFill), in: Capsule()) // ✦ single consistent surface, adapts to dark mode
    }

    // ✦ Rotten Tomatoes chip — tomato for critics, audience icon otherwise.
    @ViewBuilder
    private func rottenTomatoesChip(rating: MovieRating, value: Double) -> some View {
        ratingChip {
            if rating.type == "critic" {
                Text((value >= 6.0) ? "🍅" : "🟢") // ✦ fresh vs. rotten at a glance
            } else {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.orange)
            }
            Text(formatRating(value))
        }
    }

    // ✦ IMDb chip — recognizable gold badge with dark text (high contrast) and a full-chip tap target.
    @ViewBuilder
    private func imdbChip(value: Double?, url: URL?) -> some View {
        let chip = ratingChip {
            Text("IMDb")
                .font(.caption)
                .fontWeight(.heavy)
                .foregroundColor(.black) // ✦ legible dark-on-gold like the real IMDb badge
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Color(red: 0.96, green: 0.78, blue: 0.0),
                    in: RoundedRectangle(cornerRadius: 3, style: .continuous)
                )

            if let value {
                Text("\(formatRating(value)) / 10") // ✦ spell out the scale for clarity
            } else {
                Text("View")
            }

            if url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }

        if let url {
            Link(destination: url) { chip }
                .contentShape(Capsule()) // ✦ entire 36pt capsule is tappable — far better target than the old caption2 link
        } else {
            chip
        }
    }

    // ✦ Unified rating chips (RT + IMDb) in a width-aware flow so they wrap to a
    //   second line when sitting in the narrower column beside the poster.
    private func ratingsView(ratings: [MovieRating], imdbID: String?) -> some View {
        let imdbURL = imdbID.flatMap { URL(string: "https://www.imdb.com/title/\($0)/") }
        let rtRatings = ratings.filter { $0.image?.contains("rottentomatoes") == true }
        let imdbRatings = ratings.filter { $0.image?.contains("imdb") == true }

        // Build the ordered chip list once: RT chips, then IMDb (or a link-only fallback).
        var chips: [RatingChipModel] = rtRatings.compactMap { rating in
            rating.value.map { .rottenTomatoes(rating: rating, value: $0) }
        }
        chips += imdbRatings.map { .imdb(id: $0.computedId, value: $0.value, url: imdbURL) }
        if imdbRatings.isEmpty, let url = imdbURL {
            chips.append(.imdb(id: "imdb-link", value: nil, url: url))
        }

        return WrappingFlowLayout(chips, spacing: 8) { chip in
            switch chip {
            case .rottenTomatoes(let rating, let value):
                rottenTomatoesChip(rating: rating, value: value)
            case .imdb(_, let value, let url):
                imdbChip(value: value, url: url)
            }
        }
    }

    private func genrePillsView(genres: [MovieGenre]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genres")
                .font(.headline)

            SimpleFlowLayout(genres, spacing: 8) { genre in
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

    private func countriesView(countries: [MovieCountry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Countries")
                .font(.headline)

            SimpleFlowLayout(countries, spacing: 8) { country in
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
    
    // Device-specific grid columns
    private var gridColumns: [GridItem] {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: 3 columns for better use of space
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        } else {
            // iPhone: 2 columns for optimal readability
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
        #else
        // macOS fallback
        return [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        #endif
    }
    
    private func castView(cast: [MovieRole]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Device-specific grid layouts
            LazyVGrid(columns: gridColumns, spacing: 16) {
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
                            // ✦ Fixed 2:3 portrait box that fills the grid column, so every
                            //   photo is identical in size regardless of source resolution.
                            //   Color.clear + aspectRatio defines the box; the image fills &
                            //   clips into it (replaces fragile UIScreen pixel-width math).
                            Color.clear
                                .aspectRatio(2.0 / 3.0, contentMode: .fit) // ✦ uniform portrait frame
                                .overlay {
                                    AsyncImage(url: thumbnailURL(for: role.thumb)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill() // ✦ fill the box edge-to-edge, crop overflow
                                        case .empty:
                                            ProgressView()
                                        default:
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.gray.opacity(0.6))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity) // ✦ span full card width on any device
                                .background(Color.gray.opacity(0.15)) // ✦ placeholder backing
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)) // ✦ continuous curve

                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.tag)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text(role.role ?? " ") // ✦ always render (even when nil) to reserve space
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading) // ✦ reserve consistent text height → uniform cards
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
        .padding(.horizontal, 16)
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
                movieIMDbID: movieMetadata?.imdbID,
                movieMetadata: movieMetadata
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
        guard plexService.selectedSessionIndex < videoSessions.count else {
            print("⚠️ MainView: selectedSessionIndex \(plexService.selectedSessionIndex) is out of bounds for \(videoSessions.count) sessions")
            return
        }

        let currentSession = videoSessions[plexService.selectedSessionIndex]
        print("🎬 MainView: Loading metadata for session \(plexService.selectedSessionIndex): \(currentSession.title ?? "Unknown")")

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


// Simplified flow layout for pill-shaped items (iOS 15 compatible)
struct SimpleFlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(_ items: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(createRows()), id: \.0) { rowIndex, rowItems in
                HStack(spacing: spacing) {
                    ForEach(rowItems) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func createRows() -> [(Int, [Data.Element])] {
        var rows: [(Int, [Data.Element])] = []
        var currentRow: [Data.Element] = []
        var rowIndex = 0
        
        // For simplicity, we'll put 3-4 items per row
        // This works well for genre/country pills
        let itemsPerRow = 3
        
        for item in items {
            currentRow.append(item)
            
            if currentRow.count == itemsPerRow {
                rows.append((rowIndex, currentRow))
                currentRow = []
                rowIndex += 1
            }
        }
        
        // Add remaining items
        if !currentRow.isEmpty {
            rows.append((rowIndex, currentRow))
        }
        
        return rows
    }
}

// ✦ One rating chip's data, so a heterogeneous chip list (RT + IMDb) can flow as Identifiable items.
private enum RatingChipModel: Identifiable {
    case rottenTomatoes(rating: MovieRating, value: Double)
    case imdb(id: String, value: Double?, url: URL?)

    var id: String {
        switch self {
        case .rottenTomatoes(let rating, _): return "rt-\(rating.computedId)"
        case .imdb(let id, _, _): return "imdb-\(id)"
        }
    }
}

// ✦ Width-aware wrapping layout — lays items left-to-right and wraps to the next line
//   based on the available width (unlike SimpleFlowLayout's fixed items-per-row chunking).
//   iOS 15-safe (alignmentGuide technique; the Layout protocol is iOS 16+).
struct WrappingFlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    init(_ items: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            generate(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generate(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > g.size.width { // ✦ doesn't fit — wrap to next line
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if item.id == items.last?.id {
                            width = 0 // last item: reset for the next layout pass
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item.id == items.last?.id {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(heightReader($totalHeight))
    }

    // Reports the laid-out content height back up so the GeometryReader frame can size to it.
    private func heightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geo.size.height
            }
            return Color.clear
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

// Custom modifier to conditionally apply frame dimensions  

