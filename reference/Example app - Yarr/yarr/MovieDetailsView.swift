//
//  MovieDetailsView.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import SwiftUI
import AVKit
import WebKit
import AppKit

struct MovieDetailsView: View {
    let movieDetails: MovieDetails
    let suggestedMovies: [Movie]
    let onRelatedMovieTap: (Movie) -> Void
    let onFetchMovie: (Torrent) -> Void
    let onClose: () -> Void
    let fetchingTorrentHash: String?
    let successfulTorrentHash: String?
    let isLoading: Bool
    let isKeyboardModeActive: Bool
    
    @State private var selectedScreenshot: String?
    @State private var showingOriginalSize = false
    @State private var isSynopsisExpanded = false
    @State private var isVideoFullscreen = false
    @FocusState private var isVideoFocused: Bool
    @FocusState private var isScreenshotFocused: Bool
    
    // In-app browser states
    @State private var showingBrowser = false
    @State private var browserURL: URL?
    @FocusState private var isBrowserFocused: Bool
    
    // IMDb REST service states
    @StateObject private var imdbService = IMDbRESTService()
    @State private var imdbPlotInfo: IMDbTitleInfo?
    @State private var isLoadingIMDbPlot = false
    @State private var imdbPlotError: String?
    
    // Plot source toggle states
    @State private var showingIMDbPlot = false // Controls which plot to show
    @State private var hasIMDbPlot = false // Tracks if IMDb plot has been successfully loaded
    @State private var plotTransitionOpacity: Double = 1.0 // For smooth transitions
    @State private var showSuccessIndicator = false // Controls the green success indicator visibility
    
    // Scroll control states
    @State private var scrollTargetID: String? = nil
    @State private var currentSectionIndex: Int = 0
    
    // Popover management for person info
    @State private var activePersonPopover: String? = nil
    
    // Cached clickable elements to prevent excessive recalculation
    @State private var cachedClickableElements: [(letter: String, element: ClickableElement)] = []
    
    // Fetch button confirmation states
    @State private var confirmingFetchHash: String? = nil
    @State private var confirmationTimer: Timer? = nil
    
    // Letter mapping for keyboard navigation
    private var keyboardLetters: [String] {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return Array(letters).map { String($0) }
    }
    
    // Special keys for fetch buttons (shift+number keys)
    private var fetchButtonKeys: [String] {
        return ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"]
    }
    
    // Function to generate clickable elements and their letters
    private func generateClickableElements() -> [(letter: String, element: ClickableElement)] {
        var elements: [(letter: String, element: ClickableElement)] = []
        var letterIndex = 0
        var fetchButtonIndex = 0
        
        // Helper function to add regular element if we have enough letters
        func addElement(_ element: ClickableElement) {
            if letterIndex < keyboardLetters.count {
                elements.append((keyboardLetters[letterIndex], element))
                letterIndex += 1
            }
        }
        
        // Helper function to add fetch button with special key
        func addFetchButton(_ element: ClickableElement) {
            if fetchButtonIndex < fetchButtonKeys.count {
                elements.append((fetchButtonKeys[fetchButtonIndex], element))
                fetchButtonIndex += 1
            }
        }
        
        // Add elements in visual order (top to bottom, left to right)
        
        // 1. Main IMDb button (top-right)
        if imdbMovieURL(from: movieDetails.imdbCode) != nil {
            addElement(.mainIMDb)
        }
        
        // 2. Rotten Tomatoes button (next to IMDb)
        addElement(.mainRottenTomatoes)
        
        // 3. YTS/IMDb plot toggle button
        if hasIMDbPlot && !isLoadingIMDbPlot {
            addElement(.plotToggle)
        }
        
        // 4. Fetch buttons for torrents (using special keys)
        for torrent in movieDetails.torrents.sorted(by: { $0.quality > $1.quality }) {
            addFetchButton(.fetchButton(torrent))
        }
        
        // 5. Trailer button (if exists)
        if hasTrailer {
            addElement(.trailer)
        }
        
        // 6. Screenshots
        for (index, screenshot) in screenshots.enumerated() {
            addElement(.screenshot(screenshot, index))
        }
        
        // 7. Related movies (moved up to match new visual order)
        for movie in suggestedMovies {
            addElement(.relatedMovie(movie))
        }
        
        // 8. Cast member buttons (IMDb and birth/death info) - now comes after related movies
        if let imdbInfo = imdbPlotInfo {
            if let directors = imdbInfo.directors {
                for director in directors {
                    addElement(.personIMDb(director.name, "Director"))
                    if director.name.birthInfo != nil || (director.name.isDeceased && director.name.deathInfo != nil) {
                        addElement(.personInfo(director.name, "Director"))
                    }
                }
            }
            
            if let writers = imdbInfo.writers {
                for writer in writers {
                    addElement(.personIMDb(writer.name, "Writer"))
                    if writer.name.birthInfo != nil || (writer.name.isDeceased && writer.name.deathInfo != nil) {
                        addElement(.personInfo(writer.name, "Writer"))
                    }
                }
            }
            
            if let cast = imdbInfo.casts {
                for castMember in cast {
                    addElement(.personIMDb(castMember.name, castMember.characterString))
                    // Only add info element if person has birth/death info (matching UI condition)
                    let hasBirthOrDeathInfo = castMember.name.birthInfo != nil || (castMember.name.isDeceased && castMember.name.deathInfo != nil)
                    #if DEBUG
                    print("🎭 Cast member: \(castMember.name.displayName)")
                    print("   - Character: \(castMember.characterString)")
                    print("   - Birth info: \(castMember.name.birthInfo ?? "none")")
                    print("   - Is deceased: \(castMember.name.isDeceased)")
                    print("   - Death info: \(castMember.name.deathInfo ?? "none")")
                    print("   - Has birth/death info: \(hasBirthOrDeathInfo)")
                    #endif
                    if hasBirthOrDeathInfo {
                        addElement(.personInfo(castMember.name, castMember.characterString))
                        #if DEBUG
                        print("   - ✅ Added info element with character: \(castMember.characterString)")
                        #endif
                    } else {
                        #if DEBUG
                        print("   - ❌ Skipped info element (no birth/death info)")
                        #endif
                    }
                }
            }
        }
        
        return elements
    }
    
    // Update cached clickable elements
    private func updateClickableElements() {
        let newElements = generateClickableElements()
        
        #if DEBUG
        print("🔄 Updating clickable elements: \(newElements.count) elements")
        print("📊 Related movies count: \(suggestedMovies.count)")
        print("📊 IMDb info available: \(imdbPlotInfo != nil)")
        if let imdbInfo = imdbPlotInfo {
            print("📊 Cast count: \(imdbInfo.casts?.count ?? 0)")
            print("📊 Directors count: \(imdbInfo.directors?.count ?? 0)")
            print("📊 Writers count: \(imdbInfo.writers?.count ?? 0)")
        }
        // Show fetch buttons separately to highlight special key usage
        let fetchElements = newElements.filter { element in
            switch element.element {
            case .fetchButton(_): return true
            default: return false
            }
        }
        let nonFetchElements = newElements.filter { element in
            switch element.element {
            case .fetchButton(_): return false
            default: return true
            }
        }
        print("📊 Fetch button elements (shift+number): \(fetchElements.map { "\($0.letter): \($0.element)" })")
        print("📊 Other elements: \(nonFetchElements.map { "\($0.letter): \($0.element)" })")
        #endif
        
        cachedClickableElements = newElements
    }
    
    // Enum to represent different types of clickable elements
    private enum ClickableElement {
        case mainIMDb
        case mainRottenTomatoes
        case plotToggle
        case fetchButton(Torrent)
        case trailer
        case screenshot(String, Int)
        case personIMDb(IMDbPerson, String)
        case personInfo(IMDbPerson, String)
        case relatedMovie(Movie)
    }
    
    // Helper function to get letter for a specific element
    private func getLetterForElement(_ targetElement: ClickableElement) -> String? {
        return cachedClickableElements.first { element in
            switch (element.element, targetElement) {
            case (.mainIMDb, .mainIMDb):
                return true
            case (.mainRottenTomatoes, .mainRottenTomatoes):
                return true
            case (.plotToggle, .plotToggle):
                return true
            case (.fetchButton(let t1), .fetchButton(let t2)):
                return t1.hash == t2.hash
            case (.trailer, .trailer):
                return true
            case (.screenshot(let s1, let i1), .screenshot(let s2, let i2)):
                return s1 == s2 && i1 == i2
            case (.personIMDb(let p1, let r1), .personIMDb(let p2, let r2)):
                return p1.id == p2.id && r1 == r2
            case (.personInfo(let p1, let r1), .personInfo(let p2, let r2)):
                return p1.id == p2.id && r1 == r2
            case (.relatedMovie(let m1), .relatedMovie(let m2)):
                return m1.id == m2.id
            default:
                return false
            }
        }?.letter
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Custom Header
                customHeader
                
                // Main Content with Poster Sidebar
                HStack(spacing: 0) {
                    // Left Sidebar - Movie Poster
                    if isLoading {
                        loadingPosterSidebar
                    } else {
                        posterSidebar
                    }
                    
                    // Main Content Area
                    if isLoading {
                        loadingContentView
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Top spacer that acts as proper anchor
                                    Color.clear
                                        .frame(height: 32)
                                        .id("top")
                                    
                                    VStack(alignment: .leading, spacing: 24) {
                                        // Movie Info Section
                                        movieInfoSection
                                            .id("info")
                                        
                                        Divider()
                                        
                                        // Content Sections
                                        VStack(alignment: .leading, spacing: 24) {
                                            // Torrents - moved to be right after Plot section
                                            torrentsSection
                                                .id("torrents")
                                            
                                            // Screenshots
                                            if hasScreenshots {
                                                screenshotsSection
                                                    .id("screenshots")
                                            }
                                            
                                            // Related Movies (moved above cast so it's accessible before IMDb loads)
                                            if !suggestedMovies.isEmpty {
                                                relatedMoviesSection
                                                    .id("related")
                                            }
                                            
                                            // Crew and Cast (from IMDb)
                                            if let imdbInfo = imdbPlotInfo {
                                                crewAndCastSection(imdbInfo: imdbInfo)
                                                    .id("cast")
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 32) // Add horizontal padding to main content
                                    
                                    // Bottom spacer
                                    Color.clear
                                        .frame(height: 32)
                                        .id("bottom")
                                }
                            }
                            .onChange(of: scrollTargetID) { _, newValue in
                                if let id = newValue {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(id, anchor: .top)
                                    }
                                    DispatchQueue.main.async {
                                        self.scrollTargetID = nil
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .onChange(of: movieDetails.id) {
                            // Reset synopsis expansion state for new movie
                            isSynopsisExpanded = false
                            // Reset plot source toggle state for new movie
                            showingIMDbPlot = false
                            hasIMDbPlot = false
                            plotTransitionOpacity = 1.0
                            showSuccessIndicator = false
                            // Reset scroll position for new movie
                            currentSectionIndex = 0
                            scrollTargetID = nil
                            // Reset confirmation state for new movie
                            resetConfirmationState()
                            // Update clickable elements for new movie
                            updateClickableElements()
                            // Fetch new IMDb plot for the new movie
                            fetchIMDbPlot()
                        }

                        .onAppear {
                            // Reset scroll position when view first appears
                            currentSectionIndex = 0
                            scrollTargetID = nil
                            // Reset confirmation state
                            resetConfirmationState()
                            // Update clickable elements
                            updateClickableElements()
                            // Fetch IMDb plot when view first appears
                            fetchIMDbPlot()
                        }
                    }
                }
                .frame(maxHeight: geometry.size.height - 80) // Reserve space for header
            }
        }
        .background(Color(.windowBackgroundColor))
        .overlay(
            screenshotModal
        )
        .overlay(
            fullscreenVideoModal
        )
        .overlay(
            browserModal
        )
        .background(keyboardShortcutButtons) // Add keyboard shortcuts
    }
    
    // MARK: - Keyboard Shortcuts
    
    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        ZStack {
            // Arrow key navigation shortcuts (separate from letter shortcuts to prevent interference)
            arrowKeyShortcuts
            
            // Letter selection shortcuts
            letterSelectionShortcuts
        }
    }
    
    @ViewBuilder
    private var arrowKeyShortcuts: some View {
        ZStack {
            Button("Scroll Down") {
                scrollToNextSection()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()
            
            Button("Scroll Up") {
                scrollToPreviousSection()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(!isKeyboardModeActive)
            .hidden()
            
            Button("Scroll to Top") {
                scrollTargetID = "top"
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(!isKeyboardModeActive)
            .hidden()
            
            Button("Scroll to Bottom") {
                scrollTargetID = "bottom"
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            .disabled(!isKeyboardModeActive)
            .hidden()
        }
        // Use a stable ID so this view doesn't get rebuilt when clickable elements change
        .id("arrow-shortcuts")
    }
    
    @ViewBuilder
    private var letterSelectionShortcuts: some View {
        ZStack {
            // Letter selection shortcuts (only active in keyboard mode)
            ForEach(Array("abcdefghijklmnopqrstuvwxyz".enumerated()), id: \.offset) { index, char in
                let letter = String(char)
                Button("Select Element \(letter)") {
                    handleLetterSelection(letter)
                }
                .keyboardShortcut(KeyEquivalent(char), modifiers: [])
                .disabled(!isKeyboardModeActive)
                .hidden()
            }
            
            // Uppercase letters (A-Z) with Shift modifier
            ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated()), id: \.offset) { index, char in
                let letter = String(char)
                Button("Select Element \(letter)") {
                    handleLetterSelection(letter)
                }
                .keyboardShortcut(KeyEquivalent(char.lowercased().first!), modifiers: .shift)
                .disabled(!isKeyboardModeActive)
                .hidden()
            }
            
            // Special fetch button shortcuts (Shift+number keys for ! @ # $ % ^ & * ( ))
            let fetchKeyMappings: [(key: String, number: String)] = [
                ("!", "1"), ("@", "2"), ("#", "3"), ("$", "4"), ("%", "5"),
                ("^", "6"), ("&", "7"), ("*", "8"), ("(", "9"), (")", "0")
            ]
            
            ForEach(fetchKeyMappings, id: \.key) { mapping in
                Button("Fetch Element \(mapping.key)") {
                    handleLetterSelection(mapping.key)
                }
                .keyboardShortcut(KeyEquivalent(mapping.number.first!), modifiers: .shift)
                .disabled(!isKeyboardModeActive)
                .hidden()
            }
        }
        // This can change when clickable elements change, but won't affect arrow keys
        .id("letter-shortcuts-\(cachedClickableElements.count)")
    }
    
    private func handleLetterSelection(_ letter: String) {
        guard isKeyboardModeActive else { return }
        
        #if DEBUG
        print("🔤 Letter '\(letter)' pressed")
        print("📱 Available elements: \(cachedClickableElements.map { $0.letter })")
        #endif
        
        // Find the element that matches this letter
        if let element = cachedClickableElements.first(where: { $0.letter == letter }) {
            #if DEBUG
            print("✅ Found matching element for '\(letter)'")
            #endif
            switch element.element {
            case .mainIMDb:
                if let imdbURL = imdbMovieURL(from: movieDetails.imdbCode) {
                    openInBrowser(imdbURL)
                }
                
            case .mainRottenTomatoes:
                let rtURL = rottenTomatoesMovieURL(from: movieDetails.safeTitle)
                openInBrowser(rtURL)
                
            case .plotToggle:
                withAnimation(.easeInOut(duration: 0.3)) {
                    plotTransitionOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showingIMDbPlot.toggle()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        plotTransitionOpacity = 1.0
                    }
                }
                
            case .fetchButton(let torrent):
                handleFetchButtonSelection(torrent)
                
            case .trailer:
                isVideoFullscreen = true
                
            case .screenshot(let screenshot, _):
                selectedScreenshot = screenshot
                showingOriginalSize = true
                
            case .personIMDb(let person, let role):
                #if DEBUG
                print("🎭 Opening IMDb for \(role): \(person.displayName)")
                #endif
                if let url = URL(string: "https://www.imdb.com/name/\(person.id)/") {
                    openInBrowser(url)
                }
                
            case .personInfo(let person, let role):
                #if DEBUG
                print("ℹ️ Toggling info popover for \(role): \(person.displayName)")
                print("ℹ️ PopoverID: \(person.id)-\(role)")
                print("ℹ️ Current activePersonPopover: \(activePersonPopover ?? "nil")")
                #endif
                // Toggle the popover for this person
                let popoverID = "\(person.id)-\(role)"
                if activePersonPopover == popoverID {
                    // Popover is already open, close it
                    #if DEBUG
                    print("ℹ️ Closing popover")
                    #endif
                    activePersonPopover = nil
                } else {
                    // Popover is closed, open it
                    #if DEBUG
                    print("ℹ️ Opening popover with ID: \(popoverID)")
                    #endif
                    activePersonPopover = popoverID
                }
                
            case .relatedMovie(let movie):
                #if DEBUG
                print("🎬 Activating related movie: \(movie.safeTitle)")
                #endif
                onRelatedMovieTap(movie)
            }
        } else {
            #if DEBUG
            print("❌ No element found for letter '\(letter)'")
            #endif
        }
    }
    
    private func handleFetchButtonSelection(_ torrent: Torrent) {
        if confirmingFetchHash == torrent.hash {
            // Second press - execute the fetch
            #if DEBUG
            print("✅ Confirmed fetch for torrent: \(torrent.hash)")
            #endif
            resetConfirmationState()
            onFetchMovie(torrent)
        } else {
            // First press - start confirmation
            #if DEBUG
            print("⚠️ Starting confirmation for fetch torrent: \(torrent.hash)")
            #endif
            startConfirmation(for: torrent.hash)
        }
    }
    
    private func startConfirmation(for torrentHash: String) {
        // Cancel any existing timer
        confirmationTimer?.invalidate()
        
        // Set confirmation state
        confirmingFetchHash = torrentHash
        
        // Start 2-second timer
        confirmationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            #if DEBUG
            print("⏰ Confirmation timeout for torrent: \(torrentHash)")
            #endif
            resetConfirmationState()
        }
    }
    
    private func resetConfirmationState() {
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        confirmingFetchHash = nil
    }
    
    // Define the sections in order for navigation
    private var availableSections: [String] {
        var sections = ["info", "torrents"]
        
        #if DEBUG
        print("📋 Building available sections:")
        print("  - hasScreenshots: \(hasScreenshots)")
        print("  - suggestedMovies.isEmpty: \(suggestedMovies.isEmpty)")
        print("  - suggestedMovies.count: \(suggestedMovies.count)")
        print("  - imdbPlotInfo != nil: \(imdbPlotInfo != nil)")
        #endif
        
        if hasScreenshots {
            sections.append("screenshots")
            #if DEBUG
            print("  ✅ Added screenshots section")
            #endif
        }
        
        if !suggestedMovies.isEmpty {
            sections.append("related")
            #if DEBUG
            print("  ✅ Added related section")
            #endif
        } else {
            #if DEBUG
            print("  ❌ Skipped related section - suggestedMovies is empty")
            #endif
        }
        
        if imdbPlotInfo != nil {
            sections.append("cast")
            #if DEBUG
            print("  ✅ Added cast section")
            #endif
        }
        
        #if DEBUG
        print("  - Final sections: \(sections)")
        #endif
        
        return sections
    }
    
    private func scrollToNextSection() {
        let sections = availableSections
        
        #if DEBUG
        print("🔽 Arrow Down pressed")
        print("  - Available sections: \(sections)")
        print("  - Current section index: \(currentSectionIndex)")
        print("  - Sections count: \(sections.count)")
        #endif
        
        guard !sections.isEmpty else { 
            #if DEBUG
            print("❌ No sections available")
            #endif
            return 
        }
        
        // Ensure currentSectionIndex is valid
        if currentSectionIndex >= sections.count {
            currentSectionIndex = sections.count - 1
            #if DEBUG
            print("⚠️ Reset currentSectionIndex to \(currentSectionIndex)")
            #endif
        }
        
        let oldIndex = currentSectionIndex
        
        // If we're already at the last section, scroll to bottom
        if currentSectionIndex >= sections.count - 1 {
            #if DEBUG
            print("  - Already at last section, scrolling to bottom")
            #endif
            scrollTargetID = "bottom"
            return
        }
        
        // Move to next section
        currentSectionIndex = min(currentSectionIndex + 1, sections.count - 1)
        
        #if DEBUG
        print("  - Moving from section \(oldIndex) to \(currentSectionIndex)")
        print("  - Target section: \(sections[currentSectionIndex])")
        #endif
        
        scrollTargetID = sections[currentSectionIndex]
    }
    
    private func scrollToPreviousSection() {
        let sections = availableSections
        guard !sections.isEmpty else { return }
        
        // Ensure currentSectionIndex is valid
        if currentSectionIndex >= sections.count {
            currentSectionIndex = sections.count - 1
        }
        
        // If we're already at the first section, scroll to the top anchor
        if currentSectionIndex <= 0 {
            scrollTargetID = "top"
            currentSectionIndex = 0 // Keep at 0 so next down arrow works correctly
            return
        }
        
        // Move to previous section
        currentSectionIndex = max(currentSectionIndex - 1, 0)
        scrollTargetID = sections[currentSectionIndex]
    }
    
    // MARK: - Letter Overlay Components
    
        @ViewBuilder
    private func letterOverlay(letter: String) -> some View {
        if isKeyboardModeActive {
            Text(letter)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                .allowsHitTesting(false) // Prevent overlay from interfering with button interaction
        }
    }
    
    @ViewBuilder
    private func fetchButtonLetterOverlay(letter: String, torrentHash: String) -> some View {
        if isKeyboardModeActive {
            let isConfirming = confirmingFetchHash == torrentHash
            
            Text(letter)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isConfirming ? .black : .white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isConfirming ? Color.orange.opacity(0.9) : Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isConfirming ? Color.orange : Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                .scaleEffect(isConfirming ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isConfirming)
                .allowsHitTesting(false) // Prevent overlay from interfering with button interaction
        }
    }

    @ViewBuilder
    private func buttonWithLetterOverlay<Content: View>(
        letter: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
            
            if let letter = letter {
                letterOverlay(letter: letter)
            }
        }
    }
    
    @ViewBuilder
    private func fetchButtonWithLetterOverlay<Content: View>(
        letter: String?,
        torrentHash: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
            
            if let letter = letter {
                fetchButtonLetterOverlay(letter: letter, torrentHash: torrentHash)
            }
        }
    }
    
    @ViewBuilder
    private func visualElementWithLetterOverlay<Content: View>(
        letter: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            content()
            
            if let letter = letter {
                letterOverlay(letter: letter)
                    .offset(x: 4, y: 4) // Position in top-left corner with small offset
            }
        }
    }
    
    // MARK: - View Components
    
    private var customHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(movieDetails.safeTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                if let titleLong = movieDetails.titleLong {
                    Text(titleLong)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    private var posterSidebar: some View {
        VStack(spacing: 20) {
            // Show static placeholder if no poster image URL exists
            if let largeCoverImageURL = movieDetails.largeCoverImage, !largeCoverImageURL.isEmpty {
                CachedAsyncImage(url: URL(string: largeCoverImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.system(size: 60))
                        )
                }
                .frame(width: 300, height: 450)
                .clipped()
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            } else {
                // Static placeholder when no poster image exists
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: 60))
                    )
                    .frame(width: 300, height: 450)
                    .clipped()
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            }
            
            // YouTube Trailer below poster
            if hasTrailer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trailer")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    visualElementWithLetterOverlay(letter: getLetterForElement(.trailer)) {
                        Button(action: {
                            isVideoFullscreen = true
                        }) {
                            ZStack {
                                // Video thumbnail with movie background image
                                if let backgroundImageURL = movieDetails.backgroundImageOriginal ?? movieDetails.backgroundImage,
                                   !backgroundImageURL.isEmpty {
                                    CachedAsyncImage(url: URL(string: backgroundImageURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.black)
                                            .overlay(
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(.white)
                                            )
                                    }
                                    .frame(width: 300, height: 168) // 16:9 aspect ratio
                                    .clipped()
                                    .cornerRadius(12)
                                } else {
                                    // Fallback to black rectangle if no background image
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(width: 300, height: 168) // 16:9 aspect ratio
                                        .cornerRadius(12)
                                }
                                
                                // Dark overlay for better text readability
                                Rectangle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 300, height: 168)
                                    .cornerRadius(12)
                                
                                // Play button and text overlay
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 4)
                                    
                                    Text("Watch Trailer")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.7), radius: 2)
                                }
                                
                                // Border
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    .frame(width: 300, height: 168)
                            }
                        }
                        .buttonStyle(.plain)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(width: 300)
            }
            
            Spacer()
        }
        .frame(width: 340)
        .padding(.top, 32) // Increased top padding for better alignment
        .padding(.horizontal, 32) // Add horizontal padding on both sides
        .background(Color(.controlBackgroundColor).opacity(0.3))
        .overlay(
            // Add a subtle separator line between sidebar and main content
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity),
            alignment: .trailing
        )
    }
    
    private var loadingPosterSidebar: some View {
        VStack(spacing: 20) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
                .frame(width: 300, height: 450)
                .cornerRadius(16)
            
            // Trailer placeholder
            if hasTrailer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trailer")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 300, height: 168)
                        .cornerRadius(12)
                        .overlay(
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
                .frame(width: 300)
            }
            
            Spacer()
        }
        .frame(width: 340)
        .padding(.top, 32) // Increased top padding for better alignment
        .padding(.horizontal, 32) // Add horizontal padding on both sides
        .background(Color(.controlBackgroundColor).opacity(0.3))
        .overlay(
            // Add a subtle separator line between sidebar and main content
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity),
            alignment: .trailing
        )
    }
    
    private var movieInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Rating and Info
            HStack(spacing: 24) {
                // Runtime
                if let runtime = movieDetails.runtime, runtime > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("\(runtime) min")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Year
                if movieDetails.safeYear > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text(String(movieDetails.safeYear))
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // IMDb Rating
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    Text(String(format: "%.1f", movieDetails.safeRating))
                        .font(.title)
                        .fontWeight(.semibold)
                }
                
                // Metacritic Rating
                if let imdbInfo = imdbPlotInfo, let criticReview = imdbInfo.criticReview, let score = criticReview.score {
                    MetacriticScoreView(score: score)
                }
                
                Spacer()
                
                // IMDB Link
                if let imdbURL = imdbMovieURL(from: movieDetails.imdbCode) {
                    buttonWithLetterOverlay(letter: getLetterForElement(.mainIMDb)) {
                        Button(action: { openInBrowser(imdbURL) }) {
                            Image(nsImage: NSImage(named: "imdb-logo")!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 20)
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help("View on IMDb")
                    }
                }
                
                // Rotten Tomatoes Link
                buttonWithLetterOverlay(letter: getLetterForElement(.mainRottenTomatoes)) {
                    Button(action: { 
                        let rtURL = rottenTomatoesMovieURL(from: movieDetails.safeTitle)
                        openInBrowser(rtURL) 
                    }) {
                        Image(nsImage: NSImage(named: "rt-logo")!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 20)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .help("View on Rotten Tomatoes")
                }
            }
            
            // Genres
            FlowLayout(alignment: .leading, spacing: 8) {
                ForEach(movieDetails.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(16)
                }
            }
            
            // Languages and Countries (from IMDb)
            if let imdbInfo = imdbPlotInfo {
                languageAndCountrySection(imdbInfo: imdbInfo)
            }
            
            // Plot (from IMDb)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("Plot")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Loading indicator and source toggle
                    HStack(spacing: 8) {
                        // Loading indicator
                        if isLoadingIMDbPlot {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Loading IMDb plot...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Plot source toggle (only show when IMDb plot is available)
                        if hasIMDbPlot && !isLoadingIMDbPlot {
                            buttonWithLetterOverlay(letter: getLetterForElement(.plotToggle)) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        plotTransitionOpacity = 0.0
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        showingIMDbPlot.toggle()
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            plotTransitionOpacity = 1.0
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.2.squarepath")
                                            .font(.caption)
                                        Text(showingIMDbPlot ? "IMDb" : "YTS")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .help("Toggle between IMDb plot and YTS synopsis")
                            }
                        }
                        
                        // Success indicator (shows briefly when IMDb plot loads)
                        if showSuccessIndicator {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("IMDb plot loaded")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    
                    Spacer()
                }
                
                // Plot content with smooth transitions
                Group {
                    if showingIMDbPlot {
                        // Show IMDb plot
                        if let imdbPlot = imdbPlotInfo?.plot, !imdbPlot.isEmpty {
                            synopsisSection(synopsisText: imdbPlot)
                                .opacity(plotTransitionOpacity)
                        } else {
                            Text("IMDb plot not available")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .opacity(plotTransitionOpacity)
                        }
                    } else {
                        // Show YTS synopsis
                        let synopsisText = movieDetails.synopsis.isEmpty ? movieDetails.summary : movieDetails.synopsis
                        if !synopsisText.isEmpty {
                            synopsisSection(synopsisText: synopsisText)
                                .opacity(plotTransitionOpacity)
                        } else {
                            Text("No synopsis available for this movie.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .opacity(plotTransitionOpacity)
                        }
                    }
                }
                
                // Error message (if IMDb loading failed)
                if let imdbError = imdbPlotError, !hasIMDbPlot {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Unable to load IMDb plot: \(imdbError)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Screenshots")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(screenshots.enumerated()), id: \.element) { index, screenshot in
                        visualElementWithLetterOverlay(letter: getLetterForElement(.screenshot(screenshot, index))) {
                            CachedAsyncImage(url: URL(string: screenshot)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            }
                            .frame(width: 280, height: 158)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .onTapGesture {
                                selectedScreenshot = screenshot
                                showingOriginalSize = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 1) // Add horizontal padding for scroll content
                .padding(.trailing, 16) // Extra trailing padding to prevent edge cutoff
            }
        }
    }
    
    private func crewAndCastSection(imdbInfo: IMDbTitleInfo) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Crew & Cast")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Directors
            if let directors = imdbInfo.directors, !directors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Directors")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(directors) { director in
                            EnhancedPersonCardView(
                                person: director.name,
                                subtitle: "Director",
                                backgroundColor: Color.blue.opacity(0.05),
                                borderColor: Color.blue.opacity(0.2),
                                movieYear: movieDetails.safeYear,
                                isKeyboardModeActive: isKeyboardModeActive,
                                imdbLetter: getLetterForElement(.personIMDb(director.name, "Director")),
                                infoLetter: getLetterForElement(.personInfo(director.name, "Director")),
                                onIMDbTap: {
                                    if let url = URL(string: "https://www.imdb.com/name/\(director.name.id)/") {
                                        openInBrowser(url)
                                    }
                                },
                                activePersonPopover: $activePersonPopover
                            )
                        }
                    }
                }
            }
            
            // Writers
            if let writers = imdbInfo.writers, !writers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Writers")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(writers) { writer in
                            EnhancedPersonCardView(
                                person: writer.name,
                                subtitle: "Writer",
                                backgroundColor: Color.green.opacity(0.05),
                                borderColor: Color.green.opacity(0.2),
                                movieYear: movieDetails.safeYear,
                                isKeyboardModeActive: isKeyboardModeActive,
                                imdbLetter: getLetterForElement(.personIMDb(writer.name, "Writer")),
                                infoLetter: getLetterForElement(.personInfo(writer.name, "Writer")),
                                onIMDbTap: {
                                    if let url = URL(string: "https://www.imdb.com/name/\(writer.name.id)/") {
                                        openInBrowser(url)
                                    }
                                },
                                activePersonPopover: $activePersonPopover
                            )
                        }
                    }
                }
            }
            
            // Cast
            if let cast = imdbInfo.casts, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text("Cast")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(cast) { castMember in
                            EnhancedPersonCardView(
                                person: castMember.name,
                                subtitle: castMember.characterString,
                                backgroundColor: Color.purple.opacity(0.05),
                                borderColor: Color.purple.opacity(0.2),
                                movieYear: movieDetails.safeYear,
                                isKeyboardModeActive: isKeyboardModeActive,
                                imdbLetter: getLetterForElement(.personIMDb(castMember.name, castMember.characterString)),
                                infoLetter: getLetterForElement(.personInfo(castMember.name, castMember.characterString)),
                                onIMDbTap: {
                                    if let url = URL(string: "https://www.imdb.com/name/\(castMember.name.id)/") {
                                        openInBrowser(url)
                                    }
                                },
                                activePersonPopover: $activePersonPopover
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func personCard(person: IMDbPerson, subtitle: String, backgroundColor: Color, borderColor: Color) -> some View {
        PersonCardView(
            person: person,
            subtitle: subtitle,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            movieYear: movieDetails.safeYear,
            onIMDbTap: {
                if let url = URL(string: "https://www.imdb.com/name/\(person.id)/") {
                    openInBrowser(url)
                }
            }
        )
    }
    
    private func languageAndCountrySection(imdbInfo: IMDbTitleInfo) -> some View {
        Group {
            let hasCountries = imdbInfo.originCountries?.isEmpty == false
            let hasLanguages = imdbInfo.spokenLanguages?.isEmpty == false
            
            if hasCountries || hasLanguages {
                FlowLayout(alignment: .leading, spacing: 8) {
                    // Countries first
                    if let countries = imdbInfo.originCountries {
                        ForEach(countries, id: \.code) { country in
                            HStack(spacing: 6) {
                                Text(getCountryFlag(country.code))
                                    .font(.subheadline)
                                Text(country.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Languages second
                    if let languages = imdbInfo.spokenLanguages {
                        ForEach(languages, id: \.code) { language in
                            HStack(spacing: 6) {
                                Text(getLanguageFlag(language.code))
                                    .font(.subheadline)
                                Text(language.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    private var torrentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Downloads")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                ForEach(movieDetails.torrents.sorted { $0.quality > $1.quality }) { torrent in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(torrent.quality)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let type = torrent.type {
                                    Text(type.capitalized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Label(torrent.size, systemImage: "doc.zipper")
                                Label("\(torrent.seeds)", systemImage: "arrow.up.circle")
                                Label("\(torrent.peers)", systemImage: "person.2")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        fetchButtonWithLetterOverlay(letter: getLetterForElement(.fetchButton(torrent)), torrentHash: torrent.hash) {
                            Button(action: { onFetchMovie(torrent) }) {
                                HStack(spacing: 6) {
                                    if fetchingTorrentHash == torrent.hash {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else if successfulTorrentHash == torrent.hash {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    } else if confirmingFetchHash == torrent.hash {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.black)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    
                                    if successfulTorrentHash == torrent.hash {
                                        Text("Successfully fetched!")
                                            .foregroundColor(.white)
                                    } else if confirmingFetchHash == torrent.hash {
                                        Text("Press again to confirm")
                                            .foregroundColor(.black)
                                    } else {
                                        Text(fetchingTorrentHash == torrent.hash ? "Fetching..." : "Fetch")
                                    }
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(
                                successfulTorrentHash == torrent.hash ? .green : 
                                confirmingFetchHash == torrent.hash ? .orange : 
                                .accentColor
                            )
                            .controlSize(.regular)
                            .disabled(fetchingTorrentHash == torrent.hash || successfulTorrentHash == torrent.hash)
                        }
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    private var loadingContentView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading movie details...")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    private var relatedMoviesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Related Movies")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(suggestedMovies) { movie in
                        VStack(alignment: .leading, spacing: 8) {
                            visualElementWithLetterOverlay(letter: getLetterForElement(.relatedMovie(movie))) {
                                Button(action: { onRelatedMovieTap(movie) }) {
                                    // Show static placeholder if no poster image URL exists
                                    if let mediumCoverImageURL = movie.mediumCoverImage, !mediumCoverImageURL.isEmpty {
                                        CachedAsyncImage(url: URL(string: mediumCoverImageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .foregroundColor(.gray)
                                                        .font(.title2)
                                                )
                                        }
                                        .frame(width: 160, height: 240)
                                        .clipped()
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    } else {
                                        // Static placeholder when no poster image exists
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                                    .font(.title2)
                                            )
                                            .frame(width: 160, height: 240)
                                            .clipped()
                                            .cornerRadius(12)
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(movie.safeTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                HStack(spacing: 8) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption2)
                                        Text(String(format: "%.1f", movie.safeRating))
                                            .font(.caption)
                                    }
                                    
                                    if movie.safeYear > 0 {
                                        Text(String(movie.safeYear))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(width: 160, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 1) // Add horizontal padding for scroll content
                .padding(.trailing, 16) // Extra trailing padding to prevent edge cutoff
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasScreenshots: Bool {
        return movieDetails.mediumScreenshotImage1 != nil ||
               movieDetails.mediumScreenshotImage2 != nil ||
               movieDetails.mediumScreenshotImage3 != nil
    }
    
    private var screenshots: [String] {
        return [
            movieDetails.mediumScreenshotImage1,
            movieDetails.mediumScreenshotImage2,
            movieDetails.mediumScreenshotImage3
        ].compactMap { $0 }
    }
    
    private var screenshotModal: some View {
        Group {
            if let currentScreenshot = selectedScreenshot {
                ZStack {
                    // Background overlay
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedScreenshot = nil
                            showingOriginalSize = false
                        }
                    
                    // Modal content
                    VStack(spacing: 20) {
                        // Close button in top-right
                        HStack {
                            Spacer()
                            Button(action: {
                                selectedScreenshot = nil
                                showingOriginalSize = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        
                        // Screenshot image (always original size)
                        CachedAsyncImage(url: URL(string: getScreenshotUrl(currentScreenshot))) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading...")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 20)
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: selectedScreenshot)
                .focusable(true)
                .focused($isScreenshotFocused)
                .onAppear {
                    isScreenshotFocused = true
                }
                .onKeyPress(.escape) {
                    selectedScreenshot = nil
                    showingOriginalSize = false
                    return .handled
                }
            }
        }
    }
    
    private func getScreenshotUrl(_ mediumUrl: String) -> String {
        // Always return large/original size
        if mediumUrl.contains("medium-screenshot1") {
            return mediumUrl.replacingOccurrences(of: "medium-screenshot1", with: "large-screenshot1")
        } else if mediumUrl.contains("medium-screenshot2") {
            return mediumUrl.replacingOccurrences(of: "medium-screenshot2", with: "large-screenshot2")
        } else if mediumUrl.contains("medium-screenshot3") {
            return mediumUrl.replacingOccurrences(of: "medium-screenshot3", with: "large-screenshot3")
        }
        return mediumUrl
    }
    
    private func synopsisSection(synopsisText: String) -> some View {
        let characterLimit = 400
        let isTextLong = synopsisText.count > characterLimit
        let displayText = (isTextLong && !isSynopsisExpanded) 
            ? String(synopsisText.prefix(characterLimit)) + "..." 
            : synopsisText
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(displayText)
                .font(.body)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: isSynopsisExpanded)
            
            if isTextLong {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSynopsisExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isSynopsisExpanded ? "Show Less" : "Show More")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: isSynopsisExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var hasTrailer: Bool {
        return movieDetails.ytTrailerCode?.isEmpty == false
    }
    
    private var fullscreenVideoModal: some View {
        Group {
            if isVideoFullscreen {
                ZStack {
                    // Background
                    Color.black
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeVideo()
                        }
                    
                    // Modal content with close button
                    VStack(spacing: 0) {
                        // Close button in top-right
                        HStack {
                            Spacer()
                            Button(action: {
                                closeVideo()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        
                        // YouTube Video Player
                        YouTubePlayerView(videoID: movieDetails.ytTrailerCode ?? "")
                            .padding(40)
                            .padding(.top, 0) // Remove top padding since we have the close button
                            .onTapGesture {
                                // Prevent tap from propagating to background
                            }
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isVideoFullscreen)
                .focusable(true)
                .focused($isVideoFocused)
                .onAppear {
                    isVideoFocused = true
                }
                .onKeyPress(.escape) {
                    closeVideo()
                    return .handled
                }
                .onTapGesture(count: 2) {
                    closeVideo()
                }
            }
        }
    }
    
    // MARK: - IMDB URL Helpers
    
    private func imdbMovieURL(from imdbCode: String?) -> URL? {
        guard let imdbCode = imdbCode, !imdbCode.isEmpty else { return nil }
        return URL(string: "https://www.imdb.com/title/\(imdbCode)/")
    }
    
    private func rottenTomatoesMovieURL(from movieTitle: String) -> URL {
        // Create search query with movie title only
        let searchQuery = movieTitle
            .lowercased()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? ""
        
        return URL(string: "https://www.rottentomatoes.com/search?search=\(searchQuery)")!
    }
    
    private func imdbPersonURL(from imdbCode: String?) -> URL? {
        guard let imdbCode = imdbCode, !imdbCode.isEmpty else { return nil }
        // If the imdbCode doesn't start with "nm", prefix it
        let formattedCode = imdbCode.hasPrefix("nm") ? imdbCode : "nm\(imdbCode)"
        return URL(string: "https://www.imdb.com/name/\(formattedCode)/")
    }
    
    private func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    private func openInBrowser(_ url: URL) {
        browserURL = url
        showingBrowser = true
    }
    
    // MARK: - Helper Methods
    
    private func setupVideoPlayer() {
        // No setup needed for WebView approach
        // The video ID is passed directly to the WebView
    }
    
    private func closeVideo() {
        isVideoFullscreen = false
    }
    
    private var browserModal: some View {
        Group {
            if showingBrowser, let url = browserURL {
                ZStack {
                    // Background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeBrowser()
                        }
                    
                    // Browser window
                    VStack(spacing: 0) {
                        // Browser header with navigation controls
                        HStack(spacing: 16) {
                            // Close button
                            Button(action: closeBrowser) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            // URL display
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Text(url.host ?? url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            // Open in external browser button
                            Button(action: { 
                                openURL(url)
                                closeBrowser()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "safari")
                                        .font(.caption)
                                    Text("Open in Browser")
                                        .font(.caption)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.windowBackgroundColor))
                        .overlay(
                            Divider(),
                            alignment: .bottom
                        )
                        
                        // Web content
                        InAppWebView(url: url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 1000, height: 700)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingBrowser)
                .focusable(true)
                .focused($isBrowserFocused)
                .onAppear {
                    isBrowserFocused = true
                }
                .onKeyPress(.escape) {
                    closeBrowser()
                    return .handled
                }
            }
        }
    }
    
    private func closeBrowser() {
        showingBrowser = false
        browserURL = nil
    }
    
    private func fetchIMDbPlot() {
        // Check if we have an IMDb code
        guard let imdbCode = movieDetails.imdbCode, !imdbCode.isEmpty else {
            print("⚠️ No IMDb code available for movie: \(movieDetails.safeTitle)")
            imdbPlotInfo = nil
            imdbPlotError = "No IMDb ID available"
            hasIMDbPlot = false
            showSuccessIndicator = false
            return
        }
        
        // Reset state
        isLoadingIMDbPlot = true
        imdbPlotError = nil
        imdbPlotInfo = nil
        hasIMDbPlot = false
        showingIMDbPlot = false // Always start with YTS synopsis
        plotTransitionOpacity = 1.0
        showSuccessIndicator = false
        
        Task {
            do {
                let plotInfo = try await imdbService.fetchMoviePlot(imdbID: imdbCode)
                await MainActor.run {
                    self.imdbPlotInfo = plotInfo
                    self.isLoadingIMDbPlot = false
                    self.hasIMDbPlot = true
                    print("✅ Successfully loaded IMDb plot for: \(movieDetails.safeTitle)")
                    
                    // Update clickable elements now that IMDb data is available
                    self.updateClickableElements()
                    
                    // Check if there's no YTS synopsis - if so, automatically switch to IMDb plot
                    let ytssynopsisText = movieDetails.synopsis.isEmpty ? movieDetails.summary : movieDetails.synopsis
                    if ytssynopsisText.isEmpty {
                        // Automatically switch to IMDb plot since there's no YTS synopsis
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.plotTransitionOpacity = 0.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self.showingIMDbPlot = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.plotTransitionOpacity = 1.0
                            }
                        }
                        
                        print("🔄 Automatically switched to IMDb plot (no YTS synopsis available)")
                    }
                    
                    // Show success indicator
                    withAnimation(.easeIn(duration: 0.3)) {
                        self.showSuccessIndicator = true
                    }
                    
                    // Hide the success indicator after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            self.showSuccessIndicator = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.imdbPlotError = error.localizedDescription
                    self.isLoadingIMDbPlot = false
                    self.hasIMDbPlot = false
                    self.showSuccessIndicator = false
                    print("❌ Failed to load IMDb plot for \(movieDetails.safeTitle): \(error)")
                }
            }
        }
    }
    
    // MARK: - Flag and Language Helpers
    
    private func getCountryFlag(_ countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for v in countryCode.uppercased().unicodeScalars {
            flag.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return flag
    }
    
    private func getLanguageFlag(_ languageCode: String) -> String {
        // Map common language codes to their primary country flags
        let languageToCountry: [String: String] = [
            "en": "🇺🇸", "es": "🇪🇸", "fr": "🇫🇷", "de": "🇩🇪", "it": "🇮🇹",
            "pt": "🇵🇹", "ru": "🇷🇺", "ja": "🇯🇵", "ko": "🇰🇷", "zh": "🇨🇳",
            "ar": "🇸🇦", "hi": "🇮🇳", "th": "🇹🇭", "vi": "🇻🇳", "tr": "🇹🇷",
            "pl": "🇵🇱", "nl": "🇳🇱", "sv": "🇸🇪", "da": "🇩🇰", "no": "🇳🇴",
            "fi": "🇫🇮", "cs": "🇨🇿", "hu": "🇭🇺", "ro": "🇷🇴", "el": "🇬🇷"
        ]
        
        return languageToCountry[languageCode.lowercased()] ?? "🌐"
    }
}

// MARK: - YouTube Player WebView

struct YouTubePlayerView: NSViewRepresentable {
    let videoID: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard !videoID.isEmpty else { return }
        
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background: black; }
                .video-container {
                    position: relative;
                    width: 100%;
                    height: 100vh;
                    background: black;
                }
                iframe {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    width: 90%;
                    height: 80%;
                    border: none;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe 
                    src="https://www.youtube.com/embed/\(videoID)?autoplay=1&controls=1&rel=0&showinfo=0&modestbranding=1"
                    allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
        
        nsView.loadHTMLString(embedHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Video loaded successfully
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("YouTube player failed to load: \(error.localizedDescription)")
        }
    }
}

// MARK: - In-App Web Browser

struct InAppWebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        
        // Configure for better web browsing
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webView.configuration.defaultWebpagePreferences = preferences
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        if nsView.url != url {
            nsView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Could add loading indicator here
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page loaded successfully
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Web page failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation within the webview
            decisionHandler(.allow)
        }
    }
}

// MARK: - Enhanced PersonCardView Component for Keyboard Mode

struct EnhancedPersonCardView: View {
    let person: IMDbPerson
    let subtitle: String
    let backgroundColor: Color
    let borderColor: Color
    let movieYear: Int
    let isKeyboardModeActive: Bool
    let imdbLetter: String?
    let infoLetter: String?
    let onIMDbTap: () -> Void
    @Binding var activePersonPopover: String?
    
    private var popoverID: String {
        return "\(person.id)-\(subtitle)"
    }
    
    private var showingBirthDeathPopover: Bool {
        let isShowing = activePersonPopover == popoverID
        #if DEBUG
        if isShowing {
            print("👁️ showingBirthDeathPopover = true for \(person.displayName)")
            print("   - activePersonPopover: \(activePersonPopover ?? "nil")")
            print("   - popoverID: \(popoverID)")
        }
        #endif
        return isShowing
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatar = person.bestAvatar {
                CachedAsyncImage(url: URL(string: avatar.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
                    .frame(width: 40, height: 40)
            }
            
            // Name, role, and detailed info
            VStack(alignment: .leading, spacing: 4) {
                // Clean name without birth info
                Text(person.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Role
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Age information - cleaner format
                if let ageAtProduction = person.ageAtMovieProduction(movieYear: movieYear) {
                    if person.isDeceased {
                        if let currentAge = person.currentAge {
                            Text("Age: \(ageAtProduction) (then), \(currentAge) (deceased)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Age: \(ageAtProduction) (then)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if let currentAge = person.currentAge {
                        Text("Age: \(ageAtProduction) (then), \(currentAge) (now)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Age: \(ageAtProduction) (then)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if let currentAge = person.currentAge {
                    if person.isDeceased {
                        Text("Age at death: \(currentAge)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Age: \(currentAge)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Known for information with better formatting
                if let knownForDisplay = person.knownForDisplay {
                    Text("Known for: \(knownForDisplay)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            // Right side buttons - question mark at top, IMDb at bottom
            VStack(alignment: .trailing, spacing: 0) {
                // Birth/Death info button aligned with name at top-right
                if hasBirthOrDeathInfo {
                    HStack(spacing: 6) {
                        Button(action: {
                            activePersonPopover = popoverID
                        }) {
                            Image(systemName: "person.fill.questionmark")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("View birth and death information")
                        .popover(isPresented: Binding(
                            get: { showingBirthDeathPopover },
                            set: { newValue in
                                activePersonPopover = newValue ? popoverID : nil
                            }
                        )) {
                             VStack(alignment: .leading, spacing: 8) {
                                 // Birth information
                                 if let birthInfo = person.birthInfo {
                                     Text("Born: \(birthInfo)")
                                         .font(.caption)
                                 }
                                 
                                 // Death information (if deceased)
                                 if person.isDeceased, let deathInfo = person.deathInfo {
                                     Text("Died: \(deathInfo)")
                                         .font(.caption)
                                 }
                             }
                             .padding()
                             .frame(width: 200)
                         }
                        
                        // Letter overlay for info button
                        if isKeyboardModeActive, let letter = infoLetter {
                            Text(letter)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .allowsHitTesting(false)
                        }
                    }
                }
                
                Spacer()
                
                // IMDb link button at bottom
                HStack(spacing: 6) {
                    Button(action: onIMDbTap) {
                        Image(nsImage: NSImage(named: "imdb-logo")!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 16)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("View \(person.displayName) on IMDb")
                    .padding(.top, -8)
                    
                    // Letter overlay for IMDb button
                    if isKeyboardModeActive, let letter = imdbLetter {
                        Text(letter)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var hasBirthOrDeathInfo: Bool {
        return person.birthInfo != nil || (person.isDeceased && person.deathInfo != nil)
    }
}

#Preview {
    MovieDetailsView(
        movieDetails: MovieDetails(
            id: 1,
            url: "test",
            imdbCode: "test",
            title: "Sample Movie",
            titleEnglish: "Sample Movie",
            titleLong: "Sample Movie (2024)",
            slug: "sample-movie",
            year: 2024,
            rating: 8.5,
            runtime: 120,
            genres: ["Action", "Adventure"],
            likeCount: 100,
            descriptionIntro: "A sample movie for preview",
            descriptionFull: "This is a longer description of the sample movie used for preview purposes.",
            ytTrailerCode: "",
            language: "en",
            mpaRating: "PG-13",
            backgroundImage: "",
            backgroundImageOriginal: "",
            smallCoverImage: "",
            mediumCoverImage: "",
            largeCoverImage: "",
            mediumScreenshotImage1: nil,
            mediumScreenshotImage2: nil,
            mediumScreenshotImage3: nil,
            largeScreenshotImage1: nil,
            largeScreenshotImage2: nil,
            largeScreenshotImage3: nil,
            cast: [],
            torrents: [],
            dateUploaded: "",
            dateUploadedUnix: 0
        ),
        suggestedMovies: [],
        onRelatedMovieTap: { _ in },
        onFetchMovie: { _ in },
        onClose: { },
        fetchingTorrentHash: nil,
        successfulTorrentHash: nil,
        isLoading: false,
        isKeyboardModeActive: false
    )
}

// MARK: - Custom Button Style

struct PressableButtonStyle: ButtonStyle {
    let isSmall: Bool
    
    init(isSmall: Bool = false) {
        self.isSmall = isSmall
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: isSmall ? 8 : 12)
                    .fill(Color(hex: "#F5C519"))
                    .overlay(
                        RoundedRectangle(cornerRadius: isSmall ? 8 : 12)
                            .stroke(Color(hex: "#E6B800"), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.1 : 0.3),
                radius: configuration.isPressed ? 2 : 6,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color Extension

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
            (a, r, g, b) = (1, 1, 1, 0)
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

// MARK: - FlowLayout for Genre Pills

struct FlowLayout: Layout {
    var alignment: Alignment = .center
    var spacing: CGFloat = 8
    
    init(alignment: Alignment = .center, spacing: CGFloat = 8) {
        self.alignment = alignment
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        for row in result.rows {
            let rowXOffset: CGFloat
            switch alignment.horizontal {
            case .leading:
                rowXOffset = bounds.minX
            case .center:
                rowXOffset = bounds.midX - row.frame.midX
            case .trailing:
                rowXOffset = bounds.maxX - row.frame.maxX
            default:
                rowXOffset = bounds.minX
            }
            
            for item in row.items {
                let xPos = rowXOffset + item.frame.minX
                let yPos = bounds.minY + row.frame.minY + item.frame.minY
                item.subview.place(at: CGPoint(x: xPos, y: yPos), proposal: ProposedViewSize(item.frame.size))
            }
        }
    }
}

private struct FlowResult {
    let bounds: CGSize
    let rows: [Row]
    
    struct Row {
        let frame: CGRect
        let items: [Item]
    }
    
    struct Item {
        let subview: LayoutSubview
        let frame: CGRect
    }
    
    init(in bounds: CGSize, subviews: LayoutSubviews, alignment: Alignment, spacing: CGFloat) {
        var rows: [Row] = []
        var currentRow: [Item] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var y: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if !currentRow.isEmpty && rowWidth + spacing + size.width > bounds.width {
                // Start new row
                let rowFrame = CGRect(x: 0, y: y, width: rowWidth, height: rowHeight)
                rows.append(Row(frame: rowFrame, items: currentRow))
                currentRow = []
                rowWidth = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            // Add spacing before each item except the first in the row
            if !currentRow.isEmpty {
                rowWidth += spacing
            }
            
            let item = Item(
                subview: subview,
                frame: CGRect(x: rowWidth, y: 0, width: size.width, height: size.height)
            )
            currentRow.append(item)
            
            rowWidth += size.width
            rowHeight = max(rowHeight, size.height)
        }
        
        // Add final row
        if !currentRow.isEmpty {
            let rowFrame = CGRect(x: 0, y: y, width: rowWidth, height: rowHeight)
            rows.append(Row(frame: rowFrame, items: currentRow))
        }
        
        let totalHeight = rows.last?.frame.maxY ?? 0
        self.bounds = CGSize(width: bounds.width, height: totalHeight)
        self.rows = rows
    }
}

// MARK: - PersonCardView Component

struct PersonCardView: View {
    let person: IMDbPerson
    let subtitle: String
    let backgroundColor: Color
    let borderColor: Color
    let movieYear: Int
    let onIMDbTap: () -> Void
    
    @State private var showingBirthDeathPopover = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatar = person.bestAvatar {
                CachedAsyncImage(url: URL(string: avatar.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
                    .frame(width: 40, height: 40)
            }
            
            // Name, role, and detailed info
            VStack(alignment: .leading, spacing: 4) {
                // Clean name without birth info
                Text(person.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Role
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Age information - cleaner format
                if let ageAtProduction = person.ageAtMovieProduction(movieYear: movieYear) {
                    if person.isDeceased {
                        if let currentAge = person.currentAge {
                            Text("Age: \(ageAtProduction) (then), \(currentAge) (deceased)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Age: \(ageAtProduction) (then)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if let currentAge = person.currentAge {
                        Text("Age: \(ageAtProduction) (then), \(currentAge) (now)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Age: \(ageAtProduction) (then)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if let currentAge = person.currentAge {
                    if person.isDeceased {
                        Text("Age at death: \(currentAge)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Age: \(currentAge)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Known for information with better formatting
                if let knownForDisplay = person.knownForDisplay {
                    Text("Known for: \(knownForDisplay)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            // Right side buttons - question mark at top, IMDb at bottom
            VStack(alignment: .trailing, spacing: 0) {
                // Birth/Death info button aligned with name at top-right
                if hasBirthOrDeathInfo {
                    Button(action: {
                        showingBirthDeathPopover = true
                    }) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("View birth and death information")
                    .popover(isPresented: $showingBirthDeathPopover) {
                         VStack(alignment: .leading, spacing: 8) {
                             // Birth information
                             if let birthInfo = person.birthInfo {
                                 Text("Born: \(birthInfo)")
                                     .font(.caption)
                             }
                             
                             // Death information (if deceased)
                             if person.isDeceased, let deathInfo = person.deathInfo {
                                 Text("Died: \(deathInfo)")
                                     .font(.caption)
                             }
                         }
                         .padding()
                         .frame(width: 200)
                     }
                }
                
                Spacer()
                
                // IMDb link button at bottom
                Button(action: onIMDbTap) {
                    Image(nsImage: NSImage(named: "imdb-logo")!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 16)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("View \(person.displayName) on IMDb")
                .padding(.top, -8)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var hasBirthOrDeathInfo: Bool {
        return person.birthInfo != nil || (person.isDeceased && person.deathInfo != nil)
    }
}

// MARK: - Metacritic Score View

struct MetacriticScoreView: View {
    let score: Int
    
    private var scoreColor: (background: Color, text: Color) {
        switch score {
        case 61...100:
            return (background: Color(red: 0/255, green: 206/255, blue: 122/255), text: Color(red: 38/255, green: 38/255, blue: 38/255))
        case 40...60:
            return (background: Color(red: 255/255, green: 189/255, blue: 63/255), text: Color(red: 38/255, green: 38/255, blue: 38/255))
        case 1...39:
            return (background: Color(red: 255/255, green: 104/255, blue: 116/255), text: Color.white)
        default:
            return (background: Color.gray, text: Color.white)
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(scoreColor.background)
                .frame(width: 36, height: 36)
            
            Text("\(score)")
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(scoreColor.text)
        }
    } 
}