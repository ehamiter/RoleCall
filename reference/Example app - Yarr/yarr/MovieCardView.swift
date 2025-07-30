//
//  MovieCardView.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import SwiftUI

struct MovieCardView: View {
    let movie: Movie
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Movie Poster
                if let imageURL = movie.mediumCoverImage, !imageURL.isEmpty, URL(string: imageURL) != nil {
                    CachedAsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        posterPlaceholder
                    }
                    .frame(width: 200, height: 300)
                    .clipped()
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    // Show placeholder when no valid image URL exists
                    posterPlaceholder
                        .frame(width: 200, height: 300)
                        .clipped()
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // Movie Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.safeTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", movie.safeRating))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        if movie.safeYear > 0 {
                            Text(String(movie.safeYear))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let runtime = movie.runtime {
                            Text("\(runtime)m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Genres
                    if !movie.genres.isEmpty {
                        HStack {
                            ForEach(movie.genres.prefix(2), id: \.self) { genre in
                                Text(genre)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                    }
                    
                    // Quality indicators
                    HStack(spacing: 6) {
                        ForEach(movie.torrents.prefix(3), id: \.hash) { torrent in
                            Text(torrent.quality)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }
                .frame(width: 200, alignment: .leading)
            }
            
            // Spacer to push content to the top of the grid cell
            Spacer(minLength: 0)
        }
        .frame(width: 200, alignment: .top)
        .onTapGesture {
            onTap()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.title)
            )
    }
}

// MARK: - Responsive Movie Card View

struct ResponsiveMovieCardView: View {
    let movie: Movie
    let cardSize: CGSize
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: cardSize.width < 160 ? 8 : 12) {
                // Movie Poster
                if let imageURL = movie.mediumCoverImage, !imageURL.isEmpty, URL(string: imageURL) != nil {
                    CachedAsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        posterPlaceholder
                    }
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipped()
                    .cornerRadius(cardSize.width < 160 ? 12 : 16)
                    .shadow(color: .black.opacity(0.3), radius: cardSize.width < 160 ? 4 : 8, x: 0, y: cardSize.width < 160 ? 2 : 4)
                } else {
                    // Show placeholder when no valid image URL exists
                    posterPlaceholder
                        .frame(width: cardSize.width, height: cardSize.height)
                        .clipped()
                        .cornerRadius(cardSize.width < 160 ? 12 : 16)
                        .shadow(color: .black.opacity(0.3), radius: cardSize.width < 160 ? 4 : 8, x: 0, y: cardSize.width < 160 ? 2 : 4)
                }
                
                // Movie Info
                VStack(alignment: .leading, spacing: cardSize.width < 160 ? 4 : 8) {
                    Text(movie.safeTitle)
                        .font(titleFont)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: cardSize.width < 160 ? 8 : 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(captionFont)
                            Text(String(format: "%.1f", movie.safeRating))
                                .font(captionFont)
                                .fontWeight(.medium)
                        }
                        
                        if movie.safeYear > 0 {
                            Text(String(movie.safeYear))
                                .font(captionFont)
                                .foregroundColor(.secondary)
                        }
                        
                        if let runtime = movie.runtime, cardSize.width >= 160 {
                            Text("\(runtime)m")
                                .font(captionFont)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Genres (only show for larger cards)
                    if !movie.genres.isEmpty && cardSize.width >= 160 {
                        HStack {
                            ForEach(movie.genres.prefix(cardSize.width >= 180 ? 2 : 1), id: \.self) { genre in
                                Text(genre)
                                    .font(genreFont)
                                    .padding(.horizontal, cardSize.width < 160 ? 6 : 8)
                                    .padding(.vertical, cardSize.width < 160 ? 2 : 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(cardSize.width < 160 ? 6 : 8)
                            }
                            Spacer()
                        }
                    }
                    
                    // Quality indicators (only show for larger cards)
                    if cardSize.width >= 160 {
                        HStack(spacing: 6) {
                            ForEach(movie.torrents.prefix(cardSize.width >= 180 ? 3 : 2), id: \.hash) { torrent in
                                Text(torrent.quality)
                                    .font(qualityFont)
                                    .padding(.horizontal, cardSize.width < 160 ? 4 : 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: cardSize.width, alignment: .leading)
            }
            
            // Spacer to push content to the top of the grid cell
            Spacer(minLength: 0)
        }
        .frame(width: cardSize.width, alignment: .top)
        .onTapGesture {
            onTap()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    // MARK: - Responsive Fonts
    
    private var titleFont: Font {
        switch cardSize.width {
        case 0..<150:
            return .subheadline
        case 150..<180:
            return .headline
        default:
            return .headline
        }
    }
    
    private var captionFont: Font {
        switch cardSize.width {
        case 0..<150:
            return .caption2
        default:
            return .caption
        }
    }
    
    private var genreFont: Font {
        switch cardSize.width {
        case 0..<150:
            return .caption2
        default:
            return .caption2
        }
    }
    
    private var qualityFont: Font {
        switch cardSize.width {
        case 0..<150:
            return .caption2
        default:
            return .caption2
        }
    }
    
    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(cardSize.width < 160 ? .title3 : .title)
            )
    }
}

// MARK: - Preview

struct MovieCardView_Previews: PreviewProvider {
    static var previews: some View {
        MovieCardView(
            movie: Movie(
                id: 1,
                url: "https://example.com",
                imdbCode: "tt1234567",
                title: "Sample Movie Title That Might Be Long",
                titleEnglish: "Sample Movie",
                titleLong: "Sample Movie (2023)",
                slug: "sample-movie-2023",
                year: 2023,
                rating: 7.8,
                runtime: 125,
                genres: ["Action", "Adventure", "Drama"],
                summary: "A great movie about something",
                descriptionFull: "A longer description",
                synopsis: "Synopsis here",
                ytTrailerCode: "",
                language: "en",
                mpaRating: "PG-13",
                backgroundImage: "",
                backgroundImageOriginal: "",
                smallCoverImage: "",
                mediumCoverImage: "https://yts.mx/assets/images/movies/sample/medium-cover.jpg",
                largeCoverImage: "",
                state: "ok",
                torrents: [
                    Torrent(
                        url: "https://example.com",
                        hash: "hash",
                        quality: "1080p",
                        type: "bluray",
                        isRepack: "0",
                        videoCodec: "x264",
                        bitDepth: "8",
                        audioChannels: "2.0",
                        seeds: 10,
                        peers: 2,
                        size: "1.44 GB",
                        sizeBytes: 1546188227,
                        dateUploaded: "2023-01-01 00:00:00",
                        dateUploadedUnix: 1672531200
                    )
                ],
                dateUploaded: "2023-01-01 00:00:00",
                dateUploadedUnix: 1672531200
            ),
            onTap: {}
        )
        .padding()
    }
} 