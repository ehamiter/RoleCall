//
//  MovieViewModel.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import Foundation
import SwiftUI

@MainActor
class MovieViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var searchResults: [Movie] = []
    @Published var selectedMovie: MovieDetails?
    @Published var suggestedMovies: [Movie] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var isLoadingDetails = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var showingMovieDetails = false
    
    @Published var filters = MovieFilters()
    
    // Pagination properties
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var totalMovieCount = 0
    @Published var searchCurrentPage = 1
    @Published var searchTotalPages = 1
    @Published var searchTotalMovieCount = 0
    
    // Indicates whether the user has explicitly submitted a search (via Return key or Search button).
    @Published var searchSubmitted: Bool = false
    
    // Track the committed search text (what was actually searched) vs draft text (what user is typing)
    private var committedSearchText: String = ""
    
    private let apiService: MovieAPIService
    
    // Debug logging state for currentMovies
    private var lastLogTime: Date = Date.distantPast
    private var lastMovieCount: Int = -1
    
    init(settings: SettingsModel? = nil) {
        self.apiService = MovieAPIService(settings: settings)
        
        Task {
            await loadMovies()
        }
    }
    
    // MARK: - Public Methods
    
    func loadMovies(page: Int? = nil) async {
        let targetPage = page ?? currentPage
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("📡 loadMovies called:")
        print("  - Requesting limit: \(filters.maxLimit)")
        print("  - Page: \(targetPage)")
        #endif
        
        do {
            let result = try await apiService.fetchMovies(
                limit: filters.maxLimit,
                page: targetPage,
                quality: filters.apiQuality,
                minimumRating: filters.minimumRating,
                queryTerm: searchSubmitted ? searchText : nil,
                genre: filters.apiGenre,
                sortBy: filters.sortBy,
                orderBy: filters.orderBy,
                withRTRatings: true
            )
            
            movies = result.movies
            currentPage = result.currentPage
            totalPages = result.totalPages
            totalMovieCount = result.totalCount
            
            #if DEBUG
            print("📊 loadMovies response:")
            print("  - Requested limit: \(filters.maxLimit)")
            print("  - API returned limit: \(result.limit)")
            print("  - Movies received: \(result.movies.count)")
            print("  - Total movie count: \(result.totalCount)")
            print("  - Current page: \(result.currentPage)")
            print("  - Total pages: \(result.totalPages)")
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("❌ loadMovies() failed: \(error.localizedDescription)")
            #endif
        }
        
        isLoading = false
    }
    
    func searchMovies(page: Int? = nil) async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        let targetPage = page ?? searchCurrentPage
        
        // Commit the current search text
        committedSearchText = searchText
        
        // Clear previous search results immediately to prevent showing stale data
        if page == nil || page == 1 {
            searchResults = []
        }
        
        isSearching = true
        errorMessage = nil
        
        // Mark that a search has been explicitly triggered so the UI switches to search mode
        if !searchSubmitted {
            searchSubmitted = true
        }
        
        do {
            let result = try await apiService.fetchMovies(
                limit: filters.maxLimit,
                page: targetPage,
                quality: filters.apiQuality,
                minimumRating: filters.minimumRating,
                queryTerm: committedSearchText,  // Use committed text for actual search
                genre: filters.apiGenre,
                sortBy: filters.sortBy,
                orderBy: filters.orderBy,
                withRTRatings: true
            )
            
            searchResults = result.movies
            searchCurrentPage = result.currentPage
            searchTotalPages = result.totalPages
            searchTotalMovieCount = result.totalCount
            
            #if DEBUG
            print("📊 Updated search pagination state (searchMovies):")
            print("  - searchTotalPages: \(searchTotalPages)")
            print("  - searchCurrentPage: \(searchCurrentPage)")
            print("  - searchTotalMovieCount: \(searchTotalMovieCount)")
            print("  - shouldShowPagination will be: \(searchTotalMovieCount > 0)")
            print("  - searchResults updated with \(searchResults.count) movies:")
            if !searchResults.isEmpty {
                print("    First few: \(searchResults.prefix(3).map { $0.safeTitle })")
            }
            #endif
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
            #if DEBUG
            print("❌ searchMovies() failed: \(error.localizedDescription)")
            #endif
        }
        
        isSearching = false
    }
    
    func selectMovie(_ movie: Movie) async {
        isLoadingDetails = true
        selectedMovie = nil // Clear previous movie immediately
        showingMovieDetails = true
        errorMessage = nil
        
        do {
            selectedMovie = try await apiService.fetchMovieDetails(movieId: movie.id)
            suggestedMovies = try await apiService.fetchMovieSuggestions(movieId: movie.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingDetails = false
    }
    
    func dismissMovieDetails() {
        showingMovieDetails = false
        selectedMovie = nil
        
        // Force a proper refresh of the current view state after modal dismissal
        // Use a small delay to ensure modal dismissal completes first
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            _ = await MainActor.run {
                // Actually refresh the current view data instead of just sending change notification
                if isSearchActive && !searchText.isEmpty {
                    #if DEBUG
                    print("🔄 Modal dismissed - refreshing search results")
                    #endif
                    Task {
                        await searchMovies(page: searchCurrentPage)
                    }
                } else {
                    #if DEBUG
                    print("🔄 Modal dismissed - refreshing main movie list")
                    #endif
                    Task {
                        await loadMovies(page: currentPage)
                    }
                }
            }
        }
    }
    
    func clearSearch() {
        #if DEBUG
        print("🔄 clearSearch() called - resetting search state and loading main movies")
        #endif
        
        searchText = ""
        committedSearchText = ""
        searchResults = []
        searchCurrentPage = 1
        searchTotalPages = 1
        searchTotalMovieCount = 0
        
        // Reset the submitted-search flag so the UI returns to normal browsing mode
        searchSubmitted = false
        
        // Force reload the main movie list when search is cleared
        Task {
            await loadMovies(page: 1)
        }
    }
    
    func revertSearchText() {
        #if DEBUG
        print("🔄 revertSearchText() called - reverting to committed search: '\(committedSearchText)'")
        #endif
        
        searchText = committedSearchText
    }
    
    func refresh() async {
        #if DEBUG
        print("🔄 refresh() called - force reloading current view")
        print("  - isSearchActive: \(isSearchActive)")
        print("  - searchText: '\(searchText)'")
        #endif
        
        // Always force a refresh regardless of current state
        if isSearchActive && !searchText.isEmpty {
            #if DEBUG
            print("  - Refreshing search results")
            #endif
            await searchMovies(page: searchCurrentPage)
        } else {
            #if DEBUG
            print("  - Refreshing main movie list")
            #endif
            await loadMovies(page: currentPage)
        }
        
        #if DEBUG
        print("✅ refresh() completed")
        #endif
    }
    
    func applyFilters() async {
        #if DEBUG
        print("🔧 applyFilters() called:")
        print("  - isSearchActive: \(isSearchActive)")
        print("  - searchText: '\(searchText)'")
        print("  - Current filters: quality=\(filters.apiQuality ?? "All"), genre=\(filters.apiGenre ?? "All"), minRating=\(filters.minimumRating)")
        #endif
        
        // Reset pagination when filters change
        currentPage = 1
        searchCurrentPage = 1
        
        if isSearchActive {
            #if DEBUG
            print("  - Calling searchMovies() with filters")
            #endif
            await searchMovies(page: 1)
        } else {
            #if DEBUG
            print("  - Calling loadMovies() for main movie list")
            #endif
            await loadMovies(page: 1)
        }
        
        #if DEBUG
        print("🔧 applyFilters() completed")
        #endif
    }
    
    // MARK: - Computed Properties
    
    var currentMovies: [Movie] {
        let moviesArray = isSearchActive ? searchResults : movies
        
        // Only log debug info occasionally to reduce noise
        #if DEBUG
        let now = Date()
        let shouldLog = now.timeIntervalSince(lastLogTime) > 1.0 || moviesArray.count != lastMovieCount
        
        if shouldLog {
            print("🎬 currentMovies computed property called:")
            print("  - isSearchActive: \(isSearchActive)")
            print("  - searchSubmitted: \(searchSubmitted)")
            print("  - movies.count: \(movies.count)")
            print("  - searchResults.count: \(searchResults.count)")
            print("  - Using: \(isSearchActive ? "searchResults" : "movies") array with \(moviesArray.count) movies")
            if !moviesArray.isEmpty {
                print("  - First few movies: \(moviesArray.prefix(3).map { $0.safeTitle })")
            }
            lastLogTime = now
            lastMovieCount = moviesArray.count
        }
        #endif
        
        // Deduplicate movies by ID to prevent SwiftUI ForEach issues
        var uniqueMovies: [Movie] = []
        var seenIDs: Set<Int> = []
        
        for movie in moviesArray {
            if !seenIDs.contains(movie.id) {
                seenIDs.insert(movie.id)
                uniqueMovies.append(movie)
            } else {
                #if DEBUG
                print("⚠️ Skipping duplicate movie ID: \(movie.id) (\(movie.safeTitle))")
                #endif
            }
        }
        
        #if DEBUG
        if shouldLog {
            print("  - Returning \(uniqueMovies.count) unique movies")
        }
        #endif
        
        return uniqueMovies
    }
    
    var isSearchActive: Bool {
        // Only treat search as active after the user has explicitly submitted a search.
        return searchSubmitted
    }
    
    // Current pagination state
    var activePage: Int {
        return isSearchActive ? searchCurrentPage : currentPage
    }
    
    var activeTotalPages: Int {
        return isSearchActive ? searchTotalPages : totalPages
    }
    
    var activeTotalCount: Int {
        return isSearchActive ? searchTotalMovieCount : totalMovieCount
    }
    
    var canGoToPreviousPage: Bool {
        return activePage > 1
    }
    
    var canGoToNextPage: Bool {
        return activePage < activeTotalPages
    }
    
    var shouldShowPagination: Bool {
        // This property is deprecated - pagination should always show when movies are present
        // Kept for compatibility, but the view now handles visibility differently
        let result = !currentMovies.isEmpty
        #if DEBUG
        print("🔍 shouldShowPagination calculation (deprecated):")
        print("  - isSearchActive: \(isSearchActive)")
        print("  - searchText: '\(searchText)'")
        print("  - totalPages: \(totalPages)")
        print("  - searchTotalPages: \(searchTotalPages)")
        print("  - activeTotalPages: \(activeTotalPages)")
        print("  - currentMovies.count: \(currentMovies.count)")
        print("  - shouldShowPagination: \(result)")
        #endif
        return result
    }
    
    // MARK: - Pagination Methods
    
    func goToPage(_ page: Int) async {
        if isSearchActive {
            searchCurrentPage = page
            await searchMovies(page: page)
        } else {
            currentPage = page
            await loadMovies(page: page)
        }
    }
    
    func goToNextPage() async {
        let nextPage = isSearchActive ? searchCurrentPage + 1 : currentPage + 1
        let maxPages = isSearchActive ? searchTotalPages : totalPages
        
        if nextPage <= maxPages {
            await goToPage(nextPage)
        }
    }
    
    func goToPreviousPage() async {
        let prevPage = isSearchActive ? searchCurrentPage - 1 : currentPage - 1
        
        if prevPage >= 1 {
            await goToPage(prevPage)
        }
    }
    
    func goToFirstPage() async {
        await goToPage(1)
    }
    
    func goToLastPage() async {
        let lastPage = isSearchActive ? searchTotalPages : totalPages
        await goToPage(lastPage)
    }
} 