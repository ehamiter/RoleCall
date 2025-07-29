//
//  TMDBServiceTests.swift
//  RoleCallTests
//
//  Created by GitHub Copilot on 7/29/25.
//

import Testing
import Foundation
@testable import RoleCall

/// Test suite for diagnosing the TMDB service initialization and first-request bug
struct TMDBServiceTests {

    // MARK: - Configuration Tests

    @Test("Configuration Service loads properly")
    func testConfigurationServiceLoading() async throws {
        let configService = ConfigurationService.shared

        // Verify configuration values are accessible
        let tmdbToken = configService.tmdbAccessToken
        let tmdbBaseURL = configService.tmdbBaseURL
        let tmdbImageBaseURL = configService.tmdbImageBaseURL

        print("🔍 Configuration Test Results:")
        print("  TMDB Token present: \(tmdbToken != nil && !tmdbToken!.isEmpty)")
        print("  TMDB Base URL: \(tmdbBaseURL ?? "nil")")
        print("  TMDB Image Base URL: \(tmdbImageBaseURL ?? "nil")")

        // Verify we have essential configuration
        #expect(tmdbToken != nil, "TMDB access token should be configured")
        #expect(!tmdbToken!.isEmpty, "TMDB access token should not be empty")
        #expect(tmdbBaseURL != nil, "TMDB base URL should be configured")
    }

    // MARK: - Service Initialization Tests

    @Test("TMDB Service initializes properly")
    func testTMDBServiceInitialization() async throws {
        // Create a fresh instance to test initialization
        let tmdbService = await TMDBService()

        // Give it a moment to initialize (simulating the timing issue)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Test configuration loading by trying to access private properties through reflection
        // This simulates the state when the user first taps an actor
        print("🔍 TMDB Service Initialization Test:")
        print("  Service created successfully")

        // We can't directly access private properties, but we can test functionality
        // by attempting an API call immediately after initialization
    }

    // MARK: - First Request Bug Replication Tests

    @Test("First actor search immediately after service creation")
    func testFirstActorSearchImmediately() async throws {
        print("🔍 Testing immediate actor search after service creation...")

        // Create service and immediately try to search
        let tmdbService = await TMDBService()
        let testActorName = "Tom Hanks"

        do {
            let searchResponse = try await tmdbService.searchPerson(name: testActorName)
            print("✅ First search succeeded: Found \(searchResponse.results.count) results")

            if let firstResult = searchResponse.results.first {
                print("  First result: \(firstResult.name) (ID: \(firstResult.id))")
            }

            #expect(searchResponse.results.count > 0, "Should find results for known actor")

        } catch let error as TMDBError {
            print("❌ First search failed with TMDB error: \(error.localizedDescription)")
            if case .missingConfiguration(let message) = error {
                print("  Configuration error: \(message)")
            }
            throw error
        } catch {
            print("❌ First search failed with unexpected error: \(error)")
            throw error
        }
    }

    @Test("Sequential actor searches to replicate bug pattern")
    func testSequentialActorSearches() async throws {
        print("🔍 Testing sequential actor searches to replicate the bug pattern...")

        let tmdbService = await TMDBService()
        let testActors = ["Tom Hanks", "Meryl Streep", "Leonardo DiCaprio"]

        for (index, actorName) in testActors.enumerated() {
            print("\n--- Search \(index + 1): \(actorName) ---")

            do {
                let searchResponse = try await tmdbService.searchPerson(name: actorName)
                print("✅ Search \(index + 1) succeeded: Found \(searchResponse.results.count) results")

                if let firstResult = searchResponse.results.first {
                    print("  Result: \(firstResult.name) (ID: \(firstResult.id))")

                    // Try to get details for the first result
                    let details = try await tmdbService.getPersonDetails(personId: firstResult.id)
                    print("  Details loaded: \(details.name)")
                }

            } catch let error as TMDBError {
                print("❌ Search \(index + 1) failed with TMDB error: \(error.localizedDescription)")

                // If first search fails but we expect subsequent ones to work,
                // this confirms the bug pattern
                if index == 0 {
                    print("  🐛 This matches the reported bug pattern - first search failed")
                }
                throw error

            } catch {
                print("❌ Search \(index + 1) failed with unexpected error: \(error)")
                throw error
            }

            // Small delay between searches
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }

    @Test("Empty or invalid actor name handling")
    func testEmptyActorNameHandling() async throws {
        print("🔍 Testing empty/invalid actor name handling...")

        let tmdbService = await TMDBService()

        // Test empty string
        do {
            let _ = try await tmdbService.searchPerson(name: "")
            print("❌ Empty name search should have failed but didn't")
            #expect(false, "Empty name search should fail")
        } catch {
            print("✅ Empty name search failed as expected: \(error)")
        }

        // Test whitespace-only string
        do {
            let _ = try await tmdbService.searchPerson(name: "   ")
            print("❌ Whitespace-only name search should have failed but didn't")
            #expect(false, "Whitespace-only name search should fail")
        } catch {
            print("✅ Whitespace-only name search failed as expected: \(error)")
        }
    }

    // MARK: - Configuration Timing Tests

    @Test("Multiple concurrent service initializations")
    func testConcurrentServiceInitializations() async throws {
        print("🔍 Testing concurrent service initializations...")

        // Create multiple services concurrently to test for race conditions
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    let service = await TMDBService()
                    print("  Service \(i) created")

                    do {
                        let searchResponse = try await service.searchPerson(name: "Tom Hanks")
                        print("  Service \(i) search succeeded: \(searchResponse.results.count) results")
                    } catch {
                        print("  Service \(i) search failed: \(error)")
                    }
                }
            }
        }
    }

    @Test("Service initialization with delay")
    func testServiceInitializationWithDelay() async throws {
        print("🔍 Testing service initialization with delay...")

        let tmdbService = await TMDBService()

        // Wait a bit to ensure configuration is fully loaded
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let searchResponse = try await tmdbService.searchPerson(name: "Tom Hanks")
        print("✅ Delayed search succeeded: Found \(searchResponse.results.count) results")

        #expect(searchResponse.results.count > 0, "Should find results after delay")
    }
}
