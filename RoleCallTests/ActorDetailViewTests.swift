//
//  ActorDetailViewTests.swift
//  RoleCallTests
//
//  Created by GitHub Copilot on 7/29/25.
//

import Testing
import Foundation
import SwiftUI
@testable import RoleCall

/// Test suite for replicating the ActorDetailView bug scenario
struct ActorDetailViewTests {

    // MARK: - Actor Detail Loading Bug Replication

    @Test("Replicate first tap failure scenario")
    func testFirstTapFailureScenario() async throws {
        print("🔍 Replicating the first tap failure scenario...")

        // Simulate app startup: create a fresh TMDB service
        let tmdbService = await TMDBService()
        let testActorName = "Tom Hanks"

        // Immediately try to load actor data (simulating first tap)
        print("🎬 Simulating first actor tap...")

        var firstAttemptError: Error?

        do {
            // This simulates what ActorDetailView.loadActorDataWithRetry does
            let searchResponse = try await tmdbService.searchPerson(name: testActorName)

            guard let firstResult = searchResponse.results.first else {
                throw TMDBError.invalidResponse
            }

            // Try to get detailed information
            async let detailsTask = tmdbService.getPersonDetails(personId: firstResult.id)
            async let creditsTask = tmdbService.getPersonMovieCredits(personId: firstResult.id)

            let (details, credits) = try await (detailsTask, creditsTask)

            print("✅ First attempt succeeded unexpectedly")
            print("  Actor: \(details.name)")
            print("  Credits: \(credits.cast.count) movies")

        } catch {
            firstAttemptError = error
            print("❌ First attempt failed as expected: \(error)")

            if let tmdbError = error as? TMDBError {
                print("  TMDB Error type: \(tmdbError)")
                if case .missingConfiguration(let message) = tmdbError {
                    print("  Configuration issue: \(message)")
                }
            }
        }

        // Wait a moment (simulating time between first and second tap)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Try again (simulating second tap)
        print("\n🎬 Simulating second actor tap...")

        do {
            let searchResponse = try await tmdbService.searchPerson(name: testActorName)

            guard let firstResult = searchResponse.results.first else {
                throw TMDBError.invalidResponse
            }

            async let detailsTask = tmdbService.getPersonDetails(personId: firstResult.id)
            async let creditsTask = tmdbService.getPersonMovieCredits(personId: firstResult.id)

            let (details, credits) = try await (detailsTask, creditsTask)

            print("✅ Second attempt succeeded")
            print("  Actor: \(details.name)")
            print("  Credits: \(credits.cast.count) movies")

            // If first failed but second succeeded, we've replicated the bug
            if firstAttemptError != nil {
                print("🐛 BUG CONFIRMED: First attempt failed, second attempt succeeded")
            }

        } catch {
            print("❌ Second attempt also failed: \(error)")

            // If both attempts failed, it might be a configuration issue
            if firstAttemptError != nil {
                print("⚠️ Both attempts failed - likely a configuration issue")
                throw error
            }
        }
    }

    @Test("Test actor detail loading with empty/invalid names")
    func testActorDetailLoadingWithInvalidNames() async throws {
        print("🔍 Testing actor detail loading with invalid names...")

        let tmdbService = await TMDBService()
        let invalidNames = ["", "   ", "NonExistentActorXYZ123"]

        for (index, actorName) in invalidNames.enumerated() {
            print("\n--- Testing name \(index + 1): '\(actorName)' ---")

            do {
                let searchResponse = try await tmdbService.searchPerson(name: actorName)

                if searchResponse.results.isEmpty {
                    print("✅ No results found for invalid/empty name (expected)")
                } else {
                    print("⚠️ Unexpected results found: \(searchResponse.results.count)")
                }

            } catch {
                print("✅ Search failed for invalid name (expected): \(error)")
            }
        }
    }

    @Test("Test rapid successive actor detail requests")
    func testRapidSuccessiveActorRequests() async throws {
        print("🔍 Testing rapid successive actor detail requests...")

        let tmdbService = await TMDBService()
        let actors = ["Tom Hanks", "Meryl Streep", "Robert De Niro"]

        // Fire off requests rapidly (simulating rapid tapping)
        await withTaskGroup(of: Void.self) { group in
            for (index, actorName) in actors.enumerated() {
                group.addTask {
                    print("🚀 Starting request \(index + 1) for \(actorName)")

                    do {
                        let searchResponse = try await tmdbService.searchPerson(name: actorName)

                        if let firstResult = searchResponse.results.first {
                            let details = try await tmdbService.getPersonDetails(personId: firstResult.id)
                            print("✅ Request \(index + 1) completed: \(details.name)")
                        }

                    } catch {
                        print("❌ Request \(index + 1) failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Configuration State Testing

    @Test("Test TMDB service configuration state")
    func testTMDBServiceConfigurationState() async throws {
        print("🔍 Testing TMDB service configuration state...")

        // Test immediate access
        let tmdbService1 = await TMDBService()
        print("Service 1 created")

        // Try immediate request
        do {
            let _ = try await tmdbService1.searchPerson(name: "Test")
            print("✅ Service 1 immediate request succeeded")
        } catch let error as TMDBError {
            if case .missingConfiguration(let message) = error {
                print("❌ Service 1 immediate request failed - configuration not ready: \(message)")
            } else {
                print("❌ Service 1 immediate request failed - other error: \(error)")
            }
        }

        // Wait and try again
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        do {
            let _ = try await tmdbService1.searchPerson(name: "Test")
            print("✅ Service 1 delayed request succeeded")
        } catch {
            print("❌ Service 1 delayed request failed: \(error)")
        }
    }

    @Test("Test actor loading with retry mechanism")
    func testActorLoadingWithRetryMechanism() async throws {
        print("🔍 Testing actor loading with retry mechanism...")

        let tmdbService = await TMDBService()
        let testActorName = "Leonardo DiCaprio"

        // This simulates the loadActorDataWithRetry method behavior
        let maxRetries = 3
        var retryCount = 0
        var lastError: Error?

        while retryCount <= maxRetries {
            print("\n--- Attempt \(retryCount + 1)/\(maxRetries + 1) ---")

            do {
                let searchResponse = try await tmdbService.searchPerson(name: testActorName)

                guard let firstResult = searchResponse.results.first else {
                    throw TMDBError.invalidResponse
                }

                async let detailsTask = tmdbService.getPersonDetails(personId: firstResult.id)
                async let creditsTask = tmdbService.getPersonMovieCredits(personId: firstResult.id)

                let (details, credits) = try await (detailsTask, creditsTask)

                print("✅ Attempt \(retryCount + 1) succeeded")
                print("  Actor: \(details.name)")
                print("  Credits: \(credits.cast.count) movies")

                // Success - break out of retry loop
                break

            } catch {
                lastError = error
                retryCount += 1

                print("❌ Attempt \(retryCount) failed: \(error)")

                if retryCount <= maxRetries {
                    print("🔄 Retrying in \(retryCount) second(s)...")
                    try await Task.sleep(nanoseconds: UInt64(retryCount * 1_000_000_000))
                } else {
                    print("💥 All retry attempts exhausted")
                    throw lastError!
                }
            }
        }
    }
}
