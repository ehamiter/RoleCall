//
//  ContentView.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import SwiftUI

struct ActiveFiltersView: View {
    @ObservedObject var filters: MovieFilters
    
    var body: some View {
        let activeFilters = getActiveFilters()
        
        if !activeFilters.isEmpty {
            HStack(spacing: 8) {
                Text("Filtering by:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                ForEach(Array(activeFilters.enumerated()), id: \.offset) { index, filter in
                    HStack(spacing: 4) {
                        Text(filter.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(filter.value)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if index < activeFilters.count - 1 {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private func getActiveFilters() -> [(name: String, value: String)] {
        var activeFilters: [(name: String, value: String)] = []
        
        if filters.quality != "All" {
            activeFilters.append((name: "Quality", value: filters.quality))
        }
        if filters.genre != "All" {
            activeFilters.append((name: "Genre", value: filters.genre))
        }
        if filters.minimumRating > 0 {
            activeFilters.append((name: "Rating", value: "\(filters.minimumRating)+ Stars"))
        }
        if filters.sortBy != "date_added" {
            let displayName = MovieFilters.sortByOptions.first { $0.0 == filters.sortBy }?.1 ?? filters.sortBy
            activeFilters.append((name: "Sort", value: displayName))
        }
        if filters.orderBy != "desc" {
            activeFilters.append((name: "Order", value: "Ascending"))
        }
        
        return activeFilters
    }
}

struct FilterBarView: View {
    @ObservedObject var filters: MovieFilters
    let onFiltersChanged: () async -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                // Filter groups organized by relevance
                filterGroup("Quality", currentValue: filters.quality) {
                    ForEach(MovieFilters.qualityOptions, id: \.self) { quality in
                        filterOption(quality, isSelected: filters.quality == quality) {
                            filters.quality = quality
                            Task { await onFiltersChanged() }
                        }
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                filterGroup("Genre", currentValue: filters.genre) {
                    ForEach(MovieFilters.genreOptions, id: \.self) { genre in
                        filterOption(genre, isSelected: filters.genre == genre) {
                            filters.genre = genre
                            Task { await onFiltersChanged() }
                        }
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                filterGroup("Rating", currentValue: "\(filters.minimumRating)+") {
                    ForEach(0...9, id: \.self) { rating in
                        filterOption("\(rating)+ Stars", isSelected: filters.minimumRating == rating) {
                            filters.minimumRating = rating
                            Task { await onFiltersChanged() }
                        }
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                // Sort controls grouped together
                HStack(spacing: 16) {
                    filterGroup("Sort", currentValue: MovieFilters.sortByOptions.first { $0.0 == filters.sortBy }?.1 ?? "Date Added") {
                        ForEach(MovieFilters.sortByOptions, id: \.0) { option in
                            filterOption(option.1, isSelected: filters.sortBy == option.0) {
                                filters.sortBy = option.0
                                Task { await onFiltersChanged() }
                            }
                        }
                    }
                    
                    // Order toggle button (more compact)
                    Button {
                        filters.orderBy = filters.orderBy == "desc" ? "asc" : "desc"
                        Task { await onFiltersChanged() }
                    } label: {
                        Image(systemName: filters.orderBy == "desc" ? "arrow.down" : "arrow.up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                    .help(filters.orderBy == "desc" ? "Descending order" : "Ascending order")
                }
                
                Spacer()
                
                // Reset button with more refined styling
                Button {
                    filters.reset()
                    Task { await onFiltersChanged() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 0.5)
                )
                .help("Reset all filters")
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)
            .background(
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color(.controlBackgroundColor),
                        Color(.controlBackgroundColor).opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Refined separator
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 0.5)
        }
    }
    
    @ViewBuilder
    private func filterGroup<Content: View>(
        _ title: String,
        currentValue: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = isFilterActive(title: title, currentValue: currentValue)
        
        Menu {
            content()
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isActive ? .accentColor : .secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        // Active indicator dot
                        if isActive {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 4, height: 4)
                        }
                    }
                    
                    Text(currentValue)
                        .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                        .foregroundColor(isActive ? .accentColor : .primary)
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isActive ? .accentColor : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? Color.accentColor.opacity(0.3) : Color(.separatorColor), lineWidth: isActive ? 1.0 : 0.5)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
    
    private func isFilterActive(title: String, currentValue: String) -> Bool {
        switch title {
        case "Quality":
            return currentValue != "All"
        case "Genre":
            return currentValue != "All"
        case "Rating":
            return currentValue != "0+"
        case "Sort":
            return currentValue != "Date Added"
        default:
            return false
        }
    }
    
    @ViewBuilder
    private func filterOption(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

struct PaginationView: View {
    @ObservedObject var viewModel: MovieViewModel
    
    var body: some View {
        // Always show pagination when there are movies to display, unless currently loading
        let hasMultiplePages = viewModel.activeTotalPages > 1
        let isCurrentlyLoading = viewModel.isLoading || viewModel.isSearching
        let hasMoviesToShow = !viewModel.currentMovies.isEmpty
        let shouldShow = hasMoviesToShow && !isCurrentlyLoading
        
        if shouldShow {
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 16) {
                    // Results info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Page")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("\(viewModel.activePage)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("of \(viewModel.activeTotalPages)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(viewModel.activeTotalCount) total results")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Pagination controls
                    HStack(spacing: 8) {
                        // First page
                        pageButton(
                            systemImage: "chevron.left.2",
                            isEnabled: viewModel.canGoToPreviousPage,
                            action: { Task { await viewModel.goToFirstPage() } }
                        )
                        .help("Go to first page")
                        
                        // Previous page
                        pageButton(
                            systemImage: "chevron.left",
                            isEnabled: viewModel.canGoToPreviousPage,
                            action: { Task { await viewModel.goToPreviousPage() } }
                        )
                        .help("Go to previous page")
                        
                        // Page numbers (show current and nearby pages)
                        pageNumberButtons
                        
                        // Next page
                        pageButton(
                            systemImage: "chevron.right",
                            isEnabled: viewModel.canGoToNextPage,
                            action: { Task { await viewModel.goToNextPage() } }
                        )
                        .help("Go to next page")
                        
                        // Last page
                        pageButton(
                            systemImage: "chevron.right.2",
                            isEnabled: viewModel.canGoToNextPage,
                            action: { Task { await viewModel.goToLastPage() } }
                        )
                        .help("Go to last page")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [
                            Color(.controlBackgroundColor).opacity(0.8),
                            Color(.controlBackgroundColor)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .onAppear {
                #if DEBUG
                print("🔍 PaginationView appeared:")
                print("  - isSearchActive: \(viewModel.isSearchActive)")
                print("  - searchText: '\(viewModel.searchText)'")
                print("  - activeTotalPages: \(viewModel.activeTotalPages)")
                print("  - activeTotalCount: \(viewModel.activeTotalCount)")
                print("  - filters.maxLimit: \(viewModel.filters.maxLimit)")
                print("  - hasMultiplePages: \(hasMultiplePages)")
                print("  - hasMoviesToShow: \(hasMoviesToShow)")
                print("  - shouldShow: \(shouldShow)")
                print("  - isLoading: \(viewModel.isLoading)")
                print("  - isSearching: \(viewModel.isSearching)")
                print("  - isCurrentlyLoading: \(isCurrentlyLoading)")
                print("  - movies count: \(viewModel.movies.count)")
                print("  - searchResults count: \(viewModel.searchResults.count)")
                print("  - currentMovies count: \(viewModel.currentMovies.count)")
                print("  - showingMovieDetails: \(viewModel.showingMovieDetails)")
                #endif
            }
        } else {
            // Debug logging when pagination is hidden
            EmptyView()
                .onAppear {
                    #if DEBUG
                    print("🔍 PaginationView hidden:")
                    print("  - isSearchActive: \(viewModel.isSearchActive)")
                    print("  - searchText: '\(viewModel.searchText)'")
                    print("  - activeTotalPages: \(viewModel.activeTotalPages)")
                    print("  - activeTotalCount: \(viewModel.activeTotalCount)")
                    print("  - filters.maxLimit: \(viewModel.filters.maxLimit)")
                    print("  - hasMultiplePages: \(hasMultiplePages)")
                    print("  - hasMoviesToShow: \(hasMoviesToShow)")
                    print("  - shouldShow: \(shouldShow)")
                    print("  - isLoading: \(viewModel.isLoading)")
                    print("  - isSearching: \(viewModel.isSearching)")
                    print("  - isCurrentlyLoading: \(isCurrentlyLoading)")
                    print("  - movies count: \(viewModel.movies.count)")
                    print("  - searchResults count: \(viewModel.searchResults.count)")
                    print("  - currentMovies count: \(viewModel.currentMovies.count)")
                    print("  - showingMovieDetails: \(viewModel.showingMovieDetails)")
                    #endif
                }
        }
    }
    
    @ViewBuilder
    private var pageNumberButtons: some View {
        let currentPage = viewModel.activePage
        let totalPages = viewModel.activeTotalPages
        
        HStack(spacing: 4) {
            // Show page numbers around current page
            let startPage = max(1, currentPage - 2)
            let endPage = min(totalPages, currentPage + 2)
            
            if startPage > 1 {
                pageNumberButton(1)
                if startPage > 2 {
                    Text("...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            
            ForEach(startPage...endPage, id: \.self) { page in
                pageNumberButton(page)
            }
            
            if endPage < totalPages {
                if endPage < totalPages - 1 {
                    Text("...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                pageNumberButton(totalPages)
            }
        }
    }
    
    @ViewBuilder
    private func pageNumberButton(_ page: Int) -> some View {
        let isCurrentPage = page == viewModel.activePage
        
        Button {
            Task { await viewModel.goToPage(page) }
        } label: {
            Text("\(page)")
                .font(.system(size: 13, weight: isCurrentPage ? .semibold : .medium))
                .foregroundColor(isCurrentPage ? .white : .primary)
                .frame(minWidth: 28, minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCurrentPage ? Color.accentColor : Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isCurrentPage ? Color.clear : Color(.separatorColor), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isCurrentPage)
        .help("Go to page \(page)")
    }
    
    @ViewBuilder
    private func pageButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(.separatorColor), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct KeyboardShortcutsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            ZStack {
                // Centered title
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Close button positioned in top-right
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            
            // Keyboard shortcuts content
            VStack(spacing: 24) {
                // Two-column layout organized by availability
                HStack(alignment: .top, spacing: 50) {
                    // Left column - General and Quick Filters (always available)
                    VStack(alignment: .leading, spacing: 32) {
                        // General section
                        shortcutGroup("General", shortcuts: [
                            ("⌘ ,", "Open Settings"),
                            ("⌘ R", "Refresh movies"),
                            ("⌘ .", "Show shortcuts"),
                            ("esc", "Close modal"),
                            ("⌘ esc", "Reset everything")
                        ])
                        
                        // Quick Filters section
                        shortcutGroup("Quick Filters", shortcuts: [
                            ("/", "Cycle sort filter"),
                            ("\\", "Toggle sort order")
                        ])
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right column - Keyboard Mode (includes navigation)
                    VStack(alignment: .leading, spacing: 32) {
                        // Keyboard Mode section (includes all keyboard-only shortcuts)
                        shortcutGroup("Keyboard Mode", shortcuts: [
                            ("⌘ ⌘", "Toggle keyboard mode"),
                            ("←", "Previous page"),
                            ("⌘ ←", "First page"),
                            ("→", "Next page"),
                            ("⌘ →", "Last page"),
                            ("↑", "Scroll up one row"),
                            ("⌘ ↑", "Scroll to top"),
                            ("↓", "Scroll down one row"),
                            ("⌘ ↓", "Scroll to bottom"),
                            ("aA - zZ", "Select item by letter")
                        ])
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            
            Spacer()
        }
        .frame(width: 650, height: 520)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func shortcutItem(_ key: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            // Keyboard shortcut display
            Text(key)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray).opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
                .frame(minWidth: 40)
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func shortcutGroup(_ title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 6) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                    shortcutItem(shortcut.0, shortcut.1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Movie Card with Letter Overlay
struct MovieCardWithOverlay: View {
    let movie: Movie
    let cardSize: CGSize
    let letter: String?
    let isKeyboardMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ResponsiveMovieCardView(
                movie: movie,
                cardSize: cardSize,
                onTap: onTap
            )
            
            // Letter overlay for keyboard mode - positioned absolutely
            if isKeyboardMode, let letter = letter {
                Text(letter)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .offset(x: 8, y: 8) // Position in top-left corner with small offset
            }
        }
    }
}

// MARK: - Keyboard Navigation Overlay
struct KeyboardNavigationOverlay: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.title2)
                .foregroundColor(.white)
            
            HStack(spacing: 32) {
                HStack(spacing: 20) {
                    Text("Movie Selection:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("a-z, A-Z")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 20) {
                    Text("Quick Filters:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        overlayShortcut("/", "Sort")
                        overlayShortcut("\\", "Order")
                    }
                }
            }
            
            Spacer()
            
            Text("⌘⌘ to exit")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    @ViewBuilder
    private func overlayShortcut(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 16, height: 16)
                .background(Color.white)
                .cornerRadius(3)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct ContentView: View {
    @StateObject private var settings = SettingsModel()
    @StateObject private var viewModel: MovieViewModel
    @State private var showingSettings = false
    @State private var showingKeyboardShortcuts = false
    @State private var remoteDownloadService: RemoteDownloadService?
    @State private var fetchSuccessMessage: String? = nil
    @State private var fetchingTorrentHash: String? = nil
    @State private var successfulTorrentHash: String? = nil
    @State private var currentScrollRow: Int = 0
    @State private var viewRefreshID = UUID() // Add unique ID to force view refresh
    @State private var needsRefreshAfterModalSearch = false // Added for layout fix
    @FocusState private var isSearchFocused: Bool
    @Binding var isKeyboardModeActive: Bool
    @State private var scrollTargetID: String? = nil
    
    // Letter mapping for keyboard navigation
    private var keyboardLetters: [String] {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return Array(letters).map { String($0) }
    }
    
    // Generate letter mappings for current movies
    private var movieLetterMappings: [String: Movie] {
        var mappings: [String: Movie] = [:]
        for (index, movie) in viewModel.currentMovies.enumerated() {
            if index < keyboardLetters.count {
                mappings[keyboardLetters[index]] = movie
            }
        }
        return mappings
    }
    
    // Computed property to determine if pagination should be shown
    // Note: This property is unused - pagination logic is now handled directly in PaginationView
    private var shouldShowPagination: Bool {
        let hasMultiplePages = viewModel.activeTotalPages > 1
        let isCurrentlyLoading = viewModel.isLoading || viewModel.isSearching
        let hasMoviesToShow = !viewModel.currentMovies.isEmpty
        let result = hasMoviesToShow && !isCurrentlyLoading
        
        #if DEBUG
        print("🔍 ContentView shouldShowPagination (unused):")
        print("  - isSearchActive: \(viewModel.isSearchActive)")
        print("  - activeTotalPages: \(viewModel.activeTotalPages)")
        print("  - activeTotalCount: \(viewModel.activeTotalCount)")
        print("  - filters.maxLimit: \(viewModel.filters.maxLimit)")
        print("  - isLoading: \(viewModel.isLoading)")
        print("  - isSearching: \(viewModel.isSearching)")
        print("  - isCurrentlyLoading: \(isCurrentlyLoading)")
        print("  - hasMultiplePages: \(hasMultiplePages)")
        print("  - hasMoviesToShow: \(hasMoviesToShow)")
        print("  - result: \(result)")
        #endif
        
        return result
    }
    
    init(isKeyboardModeActive: Binding<Bool>) {
        self._isKeyboardModeActive = isKeyboardModeActive
        let settings = SettingsModel()
        self._settings = StateObject(wrappedValue: settings)
        self._viewModel = StateObject(wrappedValue: MovieViewModel(settings: settings))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar
            
            Divider()
            
            // Active Filters View
            ActiveFiltersView(filters: viewModel.filters)
            
            // Filter Bar (replacing the red placeholder)
            FilterBarView(filters: viewModel.filters) {
                await viewModel.applyFilters()
            }
            
            Divider()
            
            // Download Progress Bar (if downloading)
            if let downloadService = remoteDownloadService, downloadService.isDownloading {
                downloadProgressView(downloadService)
            }
            
            // Success notification
            if let successMessage = fetchSuccessMessage {
                successNotificationView(successMessage)
            }
            
            // Main Content - Add explicit frame to prevent layout issues
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.currentMovies.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        movieGridView
                        
                        // Pagination View
                        PaginationView(viewModel: viewModel)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .id(viewRefreshID) // Add ID to force complete view refresh when needed
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showingMovieDetails, onDismiss: {
            // Set the flag when the movie details modal is dismissed
            self.needsRefreshAfterModalSearch = true
        }) {
            if let movieDetails = viewModel.selectedMovie {
                MovieDetailsView(
                    movieDetails: movieDetails,
                    suggestedMovies: viewModel.suggestedMovies,
                    onRelatedMovieTap: { movie in
                        Task {
                            await viewModel.selectMovie(movie)
                        }
                    },
                    onFetchMovie: { torrent in
                        handleFetchMovie(torrent)
                    },
                    onClose: {
                        viewModel.dismissMovieDetails()
                    },
                    fetchingTorrentHash: fetchingTorrentHash,
                    successfulTorrentHash: successfulTorrentHash,
                    isLoading: viewModel.isLoadingDetails,
                    isKeyboardModeActive: isKeyboardModeActive
                )
                .frame(minWidth: 1200, minHeight: 800)
            } else {
                ProgressView("Loading movie details...")
                    .frame(minWidth: 600, minHeight: 400)
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            // Focus the search bar when settings is dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showingKeyboardShortcuts) {
            KeyboardShortcutsView(isPresented: $showingKeyboardShortcuts)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            setupRemoteDownloadService()
            // Update image cache with settings
            ImageCacheService.shared.updateSettings(settings)
        }
        .background(
            // Hidden button for Command-Escape keyboard shortcut
            Button("") {
                performComprehensiveReset()
            }
            .keyboardShortcut(.escape, modifiers: .command)
            .hidden()
        )
        .background(keyboardShortcutButtons) // Use the new computed property
        .onChange(of: settings.isValid) {
            setupRemoteDownloadService()
        }
        .onChange(of: settings.enableImageCaching) {
            ImageCacheService.shared.updateSettings(settings)
        }
        .onChange(of: settings.imageCacheExpirationDays) {
            ImageCacheService.shared.updateSettings(settings)
        }
        .onChange(of: settings.maxImageCacheSizeMB) {
            ImageCacheService.shared.updateSettings(settings)
        }
        .onChange(of: viewModel.currentMovies.count) {
            // Reset scroll position when movies change
            currentScrollRow = 0
        }
        .onChange(of: viewModel.activePage) {
            // Reset scroll position when page changes
            currentScrollRow = 0
        }
        .onChange(of: viewModel.isSearchActive) { oldValue, newValue in
            // Force view refresh when switching between search and main view
            if oldValue != newValue {
                viewRefreshID = UUID()
            }
        }
        .onChange(of: viewModel.isSearching) { oldValue, newValue in
            // If a search just finished (isSearching went from true to false)
            // AND we recently dismissed the movie details modal, trigger a view refresh.
            if oldValue && !newValue && needsRefreshAfterModalSearch {
                viewRefreshID = UUID()
                needsRefreshAfterModalSearch = false // Reset the flag
            }
        }
        .onChange(of: isKeyboardModeActive) { oldValue, newValue in
            if !newValue { // Keyboard mode just turned OFF
                // Delay is important to ensure focus is set reliably
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.isSearchFocused = true
                }
            }
        }
    }
    
    // MARK: - View Components

    private var keyboardShortcutButtons: some View {
        ZStack {
            // Navigation shortcuts (only active in keyboard mode)
            Button("Next Page") {
                Task { await viewModel.goToNextPage() }
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("Previous Page") {
                Task { await viewModel.goToPreviousPage() }
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("Last Page") {
                Task { await viewModel.goToLastPage() }
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("First Page") {
                Task { await viewModel.goToFirstPage() }
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("Scroll to Top") {
                self.scrollTargetID = "top"
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("Scroll to Bottom") {
                self.scrollTargetID = "bottom"
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("Scroll Down One Row") {
                let estimatedColumnsPerRow = 3
                let newRow = currentScrollRow + 1
                let targetIndex = newRow * estimatedColumnsPerRow
                if targetIndex < viewModel.currentMovies.count {
                    currentScrollRow = newRow
                    self.scrollTargetID = "movie-\(viewModel.currentMovies[targetIndex].id)"
                } else {
                    self.scrollTargetID = "bottom"
                }
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()

            Button("Scroll Up One Row") {
                if currentScrollRow > 0 {
                    self.currentScrollRow -= 1
                    let estimatedColumnsPerRow = 3
                    let targetMovieIndex = self.currentScrollRow * estimatedColumnsPerRow
                    if !viewModel.currentMovies.isEmpty && targetMovieIndex < viewModel.currentMovies.count && targetMovieIndex >= 0 {
                        self.scrollTargetID = "movie-\(viewModel.currentMovies[targetMovieIndex].id)"
                    } else {
                        self.scrollTargetID = "top"
                    }
                } else {
                    self.scrollTargetID = "top"
                }
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()
            
            // Filter shortcuts (only active in keyboard mode)
            Button("Quick Sort Filter") {
                // Cycle through sort options
                let currentIndex = MovieFilters.sortByOptions.firstIndex(where: { $0.0 == viewModel.filters.sortBy }) ?? 0
                let nextIndex = (currentIndex + 1) % MovieFilters.sortByOptions.count
                viewModel.filters.sortBy = MovieFilters.sortByOptions[nextIndex].0
                Task { await viewModel.applyFilters() }
            }
            .keyboardShortcut("/", modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()
            
            Button("Toggle Sort Order") {
                viewModel.filters.orderBy = viewModel.filters.orderBy == "desc" ? "asc" : "desc"
                Task { await viewModel.applyFilters() }
            }
            .keyboardShortcut("\\", modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()

            // Global shortcuts (always active)
            Button("Show Shortcuts Modal") {
                showingKeyboardShortcuts = true
            }
            .keyboardShortcut(".", modifiers: .command)
            .hidden()

            Button("Show Settings") {
                showingSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
            
            // Letter selection shortcuts (only active in keyboard mode)
            letterSelectionShortcuts
        }
    }
    
    @ViewBuilder
    private var letterSelectionShortcuts: some View {
        // Lowercase letters (a-z)
        ForEach(Array("abcdefghijklmnopqrstuvwxyz".enumerated()), id: \.offset) { index, char in
            let letter = String(char)
            Button("Select Movie \(letter)") {
                if let movie = movieLetterMappings[letter] {
                    Task {
                        await viewModel.selectMovie(movie)
                    }
                }
            }
            .keyboardShortcut(KeyEquivalent(char), modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()
        }
        
        // Uppercase letters (A-Z) with Shift modifier
        ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated()), id: \.offset) { index, char in
            let letter = String(char)
            Button("Select Movie \(letter)") {
                if let movie = movieLetterMappings[letter] {
                    Task {
                        await viewModel.selectMovie(movie)
                    }
                }
            }
            .keyboardShortcut(KeyEquivalent(char.lowercased().first!), modifiers: .shift)
            .disabled(!isKeyboardModeActive)
            .hidden()
        }
    }
    
    private var searchBar: some View {
        VStack(spacing: 0) {
            if isKeyboardModeActive {
                // Keyboard Navigation Overlay (replaces search bar when active)
                KeyboardNavigationOverlay()
            } else {
                // Normal Search Bar
                HStack(spacing: 16) {
                    // Settings Button
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                    
                    // Refresh Button
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh movies (⌘R)")
                    
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    
                    TextField("Search movies (e.g., \"The Royal Tenenbaums\")", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .frame(height: 34)
                        .focused($isSearchFocused)
                        .onSubmit {
                            Task {
                                let wasFirstSearch = !viewModel.isSearchActive && !viewModel.searchText.isEmpty
                                await viewModel.searchMovies()
                                
                                // Keep focus after search, especially important for first search
                                if wasFirstSearch {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSearchFocused = true
                                    }
                                }
                            }
                        }
                        .onKeyPress(.escape) {
                            // If there was a previous search, revert to it; otherwise clear completely
                            if viewModel.isSearchActive {
                                viewModel.revertSearchText()
                            } else {
                                viewModel.clearSearch()
                            }
                            return .handled
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else if !viewModel.searchText.isEmpty {
                        Button("Search") {
                            Task {
                                let wasFirstSearch = !viewModel.isSearchActive
                                await viewModel.searchMovies()
                                
                                // Keep focus after search, especially important for first search
                                if wasFirstSearch {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSearchFocused = true
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    Spacer() // Push subsequent items to the right

                    // Connection status indicator
                    if remoteDownloadService != nil {
                        Image(systemName: "key.radiowaves.forward.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                            .help("Connected to remote server")
                    } else {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "key.radiowaves.forward.slash")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .help("Not configured - click here to configure")
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
            }
        }
    }
    
    private func downloadProgressView(_ downloadService: RemoteDownloadService) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(downloadService.downloadProgress)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            
            Divider()
        }
    }
    
    private func successNotificationView(_ message: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Dismiss") {
                    fetchSuccessMessage = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            
            Divider()
        }
        .onAppear {
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                fetchSuccessMessage = nil
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2.0)
            Text("Loading movies...")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "film")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            if viewModel.isSearchActive {
                Text("No movies found")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Try searching for a different movie title")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else {
                Text("No movies available")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Check your internet connection and try again")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var movieGridView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Invisible anchor at the top
                        Color.clear
                            .frame(height: 1)
                            .id("top")
                        
                        OptimalMovieGrid(
                            movies: Array(viewModel.currentMovies.prefix(optimalMovieCount(for: geometry.size))),
                            screenSize: geometry.size,
                            isKeyboardMode: isKeyboardModeActive,
                            keyboardLetters: keyboardLetters,
                            onMovieTap: { movie in
                                Task {
                                    await viewModel.selectMovie(movie)
                                }
                            }
                        )
                        .onAppear {
                            #if DEBUG
                            let totalAvailable = viewModel.currentMovies.count
                            let optimalCount = optimalMovieCount(for: geometry.size)
                            print("🎬 Movie Grid Display:")
                            print("  - Total movies available: \(totalAvailable)")
                            print("  - Optimal count calculated: \(optimalCount)")
                            print("  - Actually showing: \(min(totalAvailable, optimalCount))")
                            #endif
                        }
                        .id(viewModel.isSearchActive ? "search-\(viewModel.searchText)-\(viewModel.searchCurrentPage)" : "main-\(viewModel.currentPage)")
                        .padding(.horizontal, adaptivePadding(for: geometry.size.width))
                        .padding(.top, 30)
                        .padding(.bottom, 30)
                        
                        // Invisible anchor at the bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .onChange(of: scrollTargetID) { _, newValue in
                    if let id = newValue {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .top)
                        }
                        DispatchQueue.main.async {
                            self.scrollTargetID = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Dynamic Movie Count Helper
    
    private func optimalMovieCount(for screenSize: CGSize) -> Int {
        return viewModel.filters.optimalMovieCount(for: screenSize)
    }
    
    // MARK: - Responsive Grid Helpers
    
    private func adaptiveColumns(for width: CGFloat) -> [GridItem] {
        let cardWidth = adaptiveCardSize(for: width).width
        let spacing = adaptiveSpacing(for: width)
        let padding = adaptivePadding(for: width)
        let availableWidth = width - (padding * 2)
        
        // Calculate how many cards can fit
        let minColumns = 2
        let maxColumns = 5
        var columns = 1
        
        while columns < maxColumns {
            let totalSpacing = CGFloat(columns - 1) * spacing
            let totalCardWidth = CGFloat(columns) * cardWidth
            let totalWidth = totalCardWidth + totalSpacing
            
            if totalWidth <= availableWidth {
                columns += 1
            } else {
                break
            }
        }
        
        // Ensure at least minColumns
        columns = max(minColumns, columns - 1)
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
    
    private func adaptiveCardSize(for width: CGFloat) -> CGSize {
        switch width {
        case 0..<1000:
            // Small windows - compact cards
            return CGSize(width: 140, height: 210)
        case 1000..<1300:
            // Medium windows - slightly larger cards
            return CGSize(width: 160, height: 240)
        case 1300..<1600:
            // Large windows - standard cards
            return CGSize(width: 180, height: 270)
        default:
            // Extra large windows - full size cards
            return CGSize(width: 200, height: 300)
        }
    }
    
    private func adaptiveSpacing(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<1000:
            return 16
        case 1000..<1300:
            return 24
        case 1300..<1600:
            return 32
        default:
            return 40
        }
    }
    
    private func adaptivePadding(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<1000:
            return 16
        case 1000..<1300:
            return 24
        case 1300..<1600:
            return 32
        default:
            return 40
        }
    }
    
    // MARK: - Actions
    
    private func handleFetchMovie(_ torrent: Torrent) {
        // Clear any previous success state
        successfulTorrentHash = nil
        
        guard let downloadService = remoteDownloadService else {
            // Fallback to clipboard copy if settings are not configured
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.url, forType: .string)
            #endif
            print("⚠️ Settings not configured, torrent URL copied to clipboard: \(torrent.url)")
            
            // Show success message for clipboard copy
            fetchSuccessMessage = "Torrent URL copied to clipboard!"
            
            // Show success state for fetch button
            successfulTorrentHash = torrent.hash
            
            // Clear success state after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                successfulTorrentHash = nil
            }
            
            // Show alert to configure settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingSettings = true
            }
            return
        }
        
        fetchingTorrentHash = torrent.hash
        Task {
            do {
                try await downloadService.downloadAndTransferTorrent(torrent)
                print("✅ Successfully downloaded to remote server and transferred torrent")
                await MainActor.run {
                    fetchSuccessMessage = "Torrent downloaded to remote server and initialized successfully!"
                    fetchingTorrentHash = nil
                    successfulTorrentHash = torrent.hash
                    
                    // Clear success state after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        successfulTorrentHash = nil
                    }
                }
            } catch {
                print("❌ Failed to download/transfer torrent: \(error.localizedDescription)")
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    fetchingTorrentHash = nil
                }
            }
        }
    }
    
    private func setupRemoteDownloadService() {
        if settings.isValid {
            remoteDownloadService = RemoteDownloadService(settings: settings)
        } else {
            remoteDownloadService = nil
        }
    }
    
    private func performComprehensiveReset() {
        print("🔄 Performing comprehensive reset...")
        
        // Close all modals and overlays
        showingSettings = false
        showingKeyboardShortcuts = false
        viewModel.showingMovieDetails = false
        
        // Use the existing clearSearch method which properly resets all search state
        viewModel.clearSearch()
        
        // Reset all filters to defaults
        viewModel.filters.reset()
        
        // Clear any success/error messages
        fetchSuccessMessage = nil
        fetchingTorrentHash = nil
        successfulTorrentHash = nil
        
        // Clear error messages
        viewModel.errorMessage = nil
        
        // Reset scroll position
        currentScrollRow = 0
        
        // Force a complete view refresh
        viewRefreshID = UUID()
        
        // Note: clearSearch() already calls loadMovies, so we don't need to call it again
        
        // Focus on search bar so user can immediately start typing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSearchFocused = true
        }
        
        print("✅ Comprehensive reset completed - returned to main view with search focused")
    }
}

// MARK: - Optimal Movie Grid Component

struct OptimalMovieGrid: View {
    let movies: [Movie]
    let screenSize: CGSize
    let isKeyboardMode: Bool
    let keyboardLetters: [String]
    let onMovieTap: (Movie) -> Void
    
    var body: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: adaptiveSpacing, content: {
            ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
                MovieCardWithOverlay(
                    movie: movie,
                    cardSize: adaptiveCardSize,
                    letter: index < keyboardLetters.count ? keyboardLetters[index] : nil,
                    isKeyboardMode: isKeyboardMode
                ) {
                    onMovieTap(movie)
                }
                .id("movie-\(movie.id)")
            }
        })
    }
    
    // MARK: - Adaptive Properties
    
    private var adaptiveColumns: [GridItem] {
        let cardWidth = adaptiveCardSize.width
        let spacing = adaptiveSpacing
        let padding = adaptivePadding
        let availableWidth = screenSize.width - (padding * 2)
        
        let minColumns = 2
        let maxColumns = 6 // Maximum for good UX following HIG
        var columns = 1
        
        while columns < maxColumns {
            let totalSpacing = CGFloat(columns - 1) * spacing
            let totalCardWidth = CGFloat(columns) * cardWidth
            let totalWidth = totalCardWidth + totalSpacing
            
            if totalWidth <= availableWidth {
                columns += 1
            } else {
                break
            }
        }
        
        let finalColumns = max(minColumns, columns - 1)
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: finalColumns)
    }
    
    private var adaptiveCardSize: CGSize {
        switch screenSize.width {
        case 0..<1000:
            // Small windows - compact cards
            return CGSize(width: 140, height: 210)
        case 1000..<1300:
            // Medium windows - slightly larger cards
            return CGSize(width: 160, height: 240)
        case 1300..<1600:
            // Large windows - standard cards
            return CGSize(width: 180, height: 270)
        default:
            // Extra large windows - full size cards
            return CGSize(width: 200, height: 300)
        }
    }
    
    private var adaptiveSpacing: CGFloat {
        switch screenSize.width {
        case 0..<1000: return 16
        case 1000..<1300: return 24
        case 1300..<1600: return 32
        default: return 40
        }
    }
    
    private var adaptivePadding: CGFloat {
        switch screenSize.width {
        case 0..<1000: return 16
        case 1000..<1300: return 24
        case 1300..<1600: return 32
        default: return 40
        }
    }
}

#Preview {
    ContentView(isKeyboardModeActive: .constant(false))
}
