import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var plexService: PlexService
    @State private var selectedSessionIndex = 0
    @State private var movieMetadata: MovieMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
            .padding()
        }
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMovieMetadata()
        }
        .refreshable {
            // Refresh both sessions and movie metadata
            await plexService.fetchSessions()
            loadMovieMetadata()
        }
    }

    @ViewBuilder
    private var content: some View {
        let videoSessions = plexService.activeVideoSessions
        if !videoSessions.isEmpty {
            // Session selection (if multiple sessions)
            if videoSessions.count > 1 {
                sessionSelectionView(sessions: videoSessions)
            }

            // Current session info
            if selectedSessionIndex < videoSessions.count {
                let currentSession = videoSessions[selectedSessionIndex]
                sessionInfoView(session: currentSession)

                // Movie metadata and cast
                if let movie = movieMetadata {
                    movieDetailsView(movie: movie)
                }
            }
        } else {
            Text("No active video sessions")
                .foregroundColor(.secondary)
                .padding()
        }
    }

    private func sessionSelectionView(sessions: [VideoSession]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Sessions")
                .font(.headline)

            Picker("Select Session", selection: $selectedSessionIndex) {
                ForEach(0..<sessions.count, id: \.self) { index in
                    let session = sessions[index]
                    Text("\(session.title ?? "Unknown Title") - \(session.user?.title ?? "Unknown User")")
                        .tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedSessionIndex) { _, _ in
                loadMovieMetadata()
            }
        }
    }

    private func sessionInfoView(session: VideoSession) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Current Session")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Title:")
                        .fontWeight(.medium)
                    Text(session.title ?? "Unknown")
                        .foregroundColor(.secondary)
                }

                if let year = session.year {
                    HStack {
                        Text("Year:")
                            .fontWeight(.medium)
                        Text(String(year))
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("User:")
                        .fontWeight(.medium)
                    Text(session.user?.title ?? "Unknown")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Device:")
                        .fontWeight(.medium)
                    Text(session.player?.title ?? "Unknown")
                        .foregroundColor(.secondary)
                }

                if let platform = session.player?.platform {
                    HStack {
                        Text("Platform:")
                            .fontWeight(.medium)
                        Text(platform)
                            .foregroundColor(.secondary)
                    }
                }

                if let state = session.player?.state {
                    HStack {
                        Text("State:")
                            .fontWeight(.medium)
                        Text(state.capitalized)
                            .foregroundColor(state == "playing" ? .green : .orange)
                    }
                }

                // Progress information
                if let duration = session.duration, let viewOffset = session.viewOffset, duration > 0 {
                    let progress = Double(viewOffset) / Double(duration)
                    let progressPercent = Int(progress * 100)

                    HStack {
                        Text("Progress:")
                            .fontWeight(.medium)
                        Text("\(progressPercent)%")
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private func movieDetailsView(movie: MovieMetadata) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Movie Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Title:")
                        .fontWeight(.medium)
                    Text(movie.title ?? "Unknown")
                        .foregroundColor(.secondary)
                }

                if let year = movie.year {
                    HStack {
                        Text("Year:")
                            .fontWeight(.medium)
                        Text(String(year))
                            .foregroundColor(.secondary)
                    }
                }

                if let summary = movie.summary {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Summary:")
                            .fontWeight(.medium)
                        Text(summary)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let duration = movie.duration, duration > 0 {
                    let hours = duration / 3600000
                    let minutes = (duration % 3600000) / 60000
                    HStack {
                        Text("Duration:")
                            .fontWeight(.medium)
                        Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // Cast information
            if let roles = movie.roles, !roles.isEmpty {
                castView(roles: roles)
            }
        }
    }

    private func castView(roles: [MovieRole]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cast")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(roles.prefix(10), id: \.id) { role in
                    HStack {
                        Text(role.tag)
                            .fontWeight(.medium)

                        Spacer()

                        Text(role.role ?? "Character")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            if roles.count > 10 {
                Text("And \(roles.count - 10) more...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadMovieMetadata() {
        let videoSessions = plexService.activeVideoSessions
        guard !videoSessions.isEmpty,
              selectedSessionIndex < videoSessions.count else {
            return
        }

        let currentSession = videoSessions[selectedSessionIndex]

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let metadata = try await plexService.getMovieMetadata(ratingKey: "\(currentSession.id)")

                await MainActor.run {
                    if let firstMovie = metadata.mediaContainer.video?.first {
                        self.movieMetadata = firstMovie
                    }
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
}

#Preview {
    NowPlayingView(plexService: PlexService())
}
