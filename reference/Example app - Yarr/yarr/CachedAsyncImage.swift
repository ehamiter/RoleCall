//
//  CachedAsyncImage.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imageCache = ImageCacheService.shared
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var error: Error?
    
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let imageData = imageData,
               let nsImage = NSImage(data: imageData) {
                content(Image(nsImage: nsImage))
            } else {
                // Always show placeholder if we don't have a valid image
                // This covers cases where:
                // - Image is loading (isLoading = true)
                // - Image failed to load (error != nil)
                // - Image data exists but can't be converted to NSImage
                // - No image URL provided
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) {
            // Reset state when URL changes
            imageData = nil
            error = nil
            isLoading = false
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !url.isEmpty else {
            imageData = nil
            error = nil
            isLoading = false
            return
        }
        
        // Validate URL format
        guard URL(string: url) != nil else {
            imageData = nil
            error = NSError(domain: "CachedAsyncImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"])
            isLoading = false
            return
        }
        
        // Check cache first
        if let cachedData = imageCache.cachedImage(for: url) {
            // Validate that cached data can actually create an image
            if NSImage(data: cachedData) != nil {
                imageData = cachedData
                error = nil
                isLoading = false
                return
            } else {
                // Remove invalid cached data
                imageCache.removeImage(for: url)
            }
        }
        
        // Load from network
        isLoading = true
        error = nil
        imageData = nil
        
        Task {
            do {
                let data = try await imageCache.loadImage(from: url)
                await MainActor.run {
                    // Validate that the loaded data can create an image
                    if NSImage(data: data) != nil {
                        imageData = data
                        error = nil
                    } else {
                        imageData = nil
                        error = NSError(domain: "CachedAsyncImage", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    imageData = nil
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image, Placeholder == Image {
    init(url: String?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { Image(systemName: "photo") }
        )
    }
}

extension CachedAsyncImage where Placeholder == EmptyView {
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            content: content,
            placeholder: { EmptyView() }
        )
    }
}

extension CachedAsyncImage where Content == Image {
    init(
        url: String?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: placeholder
        )
    }
}

// MARK: - URL-based Initializers (for compatibility with AsyncImage)

extension CachedAsyncImage {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url?.absoluteString,
            content: content,
            placeholder: placeholder
        )
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Image {
    init(url: URL?) {
        self.init(url: url?.absoluteString)
    }
}

extension CachedAsyncImage where Placeholder == EmptyView {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url?.absoluteString,
            content: content,
            placeholder: { EmptyView() }
        )
    }
}

extension CachedAsyncImage where Content == Image {
    init(
        url: URL?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url?.absoluteString,
            content: { $0 },
            placeholder: placeholder
        )
    }
} 