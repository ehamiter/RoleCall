//
//  BugReplicationTestRunner.swift
//  RoleCallTests
//
//  Created by GitHub Copilot on 7/29/25.
//

import Testing
import Foundation
@testable import RoleCall

/// Utility for running specific bug replication tests with detailed logging
struct BugReplicationTestRunner {

    // MARK: - Main Bug Replication Test

    @Test("🐛 Complete bug replication scenario")
    func replicateCompleteBugScenario() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("🐛 COMPLETE BUG REPLICATION SCENARIO")
        print(String(repeating: "=", count: 80))
        print("Simulating: App opens → connects → shows cast → user taps actor")
        print("Expected: First tap fails, second tap works")
        print(String(repeating: "=", count: 80) + "\n")

        // Phase 1: App startup simulation
        print("📱 PHASE 1: Simulating app startup...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // This simulates what happens when the app starts up
        let configService = ConfigurationService.shared
        let tmdbService = await TMDBService()

        let initTime = CFAbsoluteTimeGetCurrent() - startTime
        print("   App initialization took: \(initTime * 1000) ms")
        print("   Configuration loaded: \(configService.tmdbAccessToken != nil)")
        print("   TMDB service created")

        // Phase 2: User interaction simulation
        print("\n🎬 PHASE 2: Simulating user tapping first cast member...")
        let firstTapTime = CFAbsoluteTimeGetCurrent()

        var firstTapSucceeded = false
        var firstTapError: Error?

        do {
            // This exactly mirrors what ActorDetailView.loadActorDataWithRetry does
            let testActorName = "Tom Hanks"
            let searchResponse = try await tmdbService.searchPerson(name: testActorName)

            guard let firstResult = searchResponse.results.first else {
                throw TMDBError.invalidResponse
            }

            // Parallel requests for details and credits
            async let detailsTask = tmdbService.getPersonDetails(personId: firstResult.id)
            async let creditsTask = tmdbService.getPersonMovieCredits(personId: firstResult.id)

            let (details, credits) = try await (detailsTask, creditsTask)

            firstTapSucceeded = true
            let firstTapDuration = CFAbsoluteTimeGetCurrent() - firstTapTime

            print("   ✅ FIRST TAP SUCCEEDED (unexpected!)")
            print("   Duration: \(firstTapDuration * 1000) ms")
            print("   Actor: \(details.name)")
            print("   Movies: \(credits.cast.count)")

        } catch {
            firstTapError = error
            let firstTapDuration = CFAbsoluteTimeGetCurrent() - firstTapTime

            print("   ❌ FIRST TAP FAILED (matches bug report!)")
            print("   Duration: \(firstTapDuration * 1000) ms")
            print("   Error: \(error)")

            if let tmdbError = error as? TMDBError {
                if case .missingConfiguration(let message) = tmdbError {
                    print("   🔍 Configuration issue: \(message)")
                }
            }
        }

        // Phase 3: Second tap simulation
        print("\n🎬 PHASE 3: User dismisses sheet and taps second cast member...")

        // Simulate time between dismissing error sheet and tapping again
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        let secondTapTime = CFAbsoluteTimeGetCurrent()
        var secondTapSucceeded = false

        do {
            let testActorName = "Meryl Streep"
            let searchResponse = try await tmdbService.searchPerson(name: testActorName)

            guard let firstResult = searchResponse.results.first else {
                throw TMDBError.invalidResponse
            }

            async let detailsTask = tmdbService.getPersonDetails(personId: firstResult.id)
            async let creditsTask = tmdbService.getPersonMovieCredits(personId: firstResult.id)

            let (details, credits) = try await (detailsTask, creditsTask)

            secondTapSucceeded = true
            let secondTapDuration = CFAbsoluteTimeGetCurrent() - secondTapTime

            print("   ✅ SECOND TAP SUCCEEDED")
            print("   Duration: \(secondTapDuration * 1000) ms")
            print("   Actor: \(details.name)")
            print("   Movies: \(credits.cast.count)")

        } catch {
            let secondTapDuration = CFAbsoluteTimeGetCurrent() - secondTapTime

            print("   ❌ SECOND TAP ALSO FAILED")
            print("   Duration: \(secondTapDuration * 1000) ms")
            print("   Error: \(error)")
        }

        // Phase 4: Analysis
        print("\n📊 PHASE 4: Bug analysis...")

        if !firstTapSucceeded && secondTapSucceeded {
            print("   🐛 BUG CONFIRMED!")
            print("   First tap failed, second tap succeeded")
            print("   This matches the exact bug report scenario")

            if let error = firstTapError as? TMDBError,
               case .missingConfiguration(let message) = error {
                print("   Root cause: Configuration timing issue")
                print("   Details: \(message)")
            }

        } else if firstTapSucceeded && secondTapSucceeded {
            print("   ✅ No bug detected - both taps worked")
            print("   Either bug is fixed or configuration was ready immediately")

        } else if !firstTapSucceeded && !secondTapSucceeded {
            print("   ⚠️ Both taps failed - likely configuration issue")
            print("   Check Config.plist file")

        } else {
            print("   🤔 Unexpected pattern - first worked, second failed")
        }

        print("\n" + String(repeating: "=", count: 80))
        print("🐛 BUG REPLICATION COMPLETE")
        print(String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Rapid Fire Test

    @Test("🔥 Rapid fire actor tap simulation")
    func rapidFireActorTapSimulation() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("🔥 RAPID FIRE ACTOR TAP SIMULATION")
        print(String(repeating: "=", count: 60))
        print("Simulating user rapidly tapping different actors")
        print(String(repeating: "=", count: 60) + "\n")

        let tmdbService = await TMDBService()
        let actors = [
            "Tom Hanks",
            "Meryl Streep",
            "Leonardo DiCaprio",
            "Jennifer Lawrence",
            "Robert De Niro"
        ]

        var results: [(String, Bool, TimeInterval, String?)] = []

        for (index, actorName) in actors.enumerated() {
            print("🎯 Tap \(index + 1): \(actorName)")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                let searchResponse = try await tmdbService.searchPerson(name: actorName)

                guard let firstResult = searchResponse.results.first else {
                    throw TMDBError.invalidResponse
                }

                let details = try await tmdbService.getPersonDetails(personId: firstResult.id)
                let duration = CFAbsoluteTimeGetCurrent() - startTime

                results.append((actorName, true, duration, nil))
                print("   ✅ Success in \(duration * 1000) ms")

            } catch {
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                results.append((actorName, false, duration, error.localizedDescription))
                print("   ❌ Failed in \(duration * 1000) ms: \(error)")
            }

            // Small delay between taps
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        print("\n📊 Rapid fire results:")
        for (actor, success, duration, error) in results {
            let status = success ? "✅" : "❌"
            let time = String(format: "%.0f", duration * 1000)
            print("   \(status) \(actor): \(time)ms" + (error != nil ? " - \(error!)" : ""))
        }

        let successCount = results.filter { $0.1 }.count
        let failureCount = results.count - successCount

        print("\n📈 Summary:")
        print("   Successes: \(successCount)/\(results.count)")
        print("   Failures: \(failureCount)/\(results.count)")

        if failureCount > 0 {
            print("   🐛 Pattern detected - some requests failing")
        } else {
            print("   ✅ All requests succeeded")
        }

        print("\n" + String(repeating: "=", count: 60))
        print("🔥 RAPID FIRE TEST COMPLETE")
        print(String(repeating: "=", count: 60) + "\n")
    }

    // MARK: - Service State Inspector

    @Test("🔍 TMDB Service state inspection")
    func tmdbServiceStateInspection() async throws {
        print("\n" + String(repeating: "=", count: 70))
        print("🔍 TMDB SERVICE STATE INSPECTION")
        print(String(repeating: "=", count: 70))
        print("Analyzing service initialization and configuration timing")
        print(String(repeating: "=", count: 70) + "\n")

        // Test 1: Immediate access
        print("🚀 Test 1: Immediate service access")
        let service1StartTime = CFAbsoluteTimeGetCurrent()
        let service1 = await TMDBService()
        let service1CreateTime = CFAbsoluteTimeGetCurrent() - service1StartTime

        print("   Service creation time: \(service1CreateTime * 1000) ms")

        // Try immediate request
        let immediateRequestTime = CFAbsoluteTimeGetCurrent()
        var immediateSuccess = false

        do {
            let _ = try await service1.searchPerson(name: "Immediate Test")
            immediateSuccess = true
            let requestDuration = CFAbsoluteTimeGetCurrent() - immediateRequestTime
            print("   ✅ Immediate request succeeded in \(requestDuration * 1000) ms")
        } catch {
            let requestDuration = CFAbsoluteTimeGetCurrent() - immediateRequestTime
            print("   ❌ Immediate request failed in \(requestDuration * 1000) ms: \(error)")
        }

        // Test 2: Delayed access
        print("\n⏰ Test 2: Delayed service access")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        let delayedRequestTime = CFAbsoluteTimeGetCurrent()
        var delayedSuccess = false

        do {
            let _ = try await service1.searchPerson(name: "Delayed Test")
            delayedSuccess = true
            let requestDuration = CFAbsoluteTimeGetCurrent() - delayedRequestTime
            print("   ✅ Delayed request succeeded in \(requestDuration * 1000) ms")
        } catch {
            let requestDuration = CFAbsoluteTimeGetCurrent() - delayedRequestTime
            print("   ❌ Delayed request failed in \(requestDuration * 1000) ms: \(error)")
        }

        // Test 3: Multiple service instances
        print("\n🔄 Test 3: Multiple service instances")

        var services: [TMDBService] = []
        var serviceResults: [Bool] = []

        for i in 1...3 {
            let service = await TMDBService()
            services.append(service)

            do {
                let _ = try await service.searchPerson(name: "Multi Test \(i)")
                serviceResults.append(true)
                print("   ✅ Service \(i): Success")
            } catch {
                serviceResults.append(false)
                print("   ❌ Service \(i): Failed - \(error)")
            }
        }

        // Analysis
        print("\n📊 Analysis:")

        if !immediateSuccess && delayedSuccess {
            print("   🐛 TIMING ISSUE DETECTED:")
            print("   - Service needs time to initialize configuration")
            print("   - This explains the first-tap failure bug")
        } else if immediateSuccess && delayedSuccess {
            print("   ✅ Service configuration is working properly")
        } else {
            print("   ⚠️ Service has persistent configuration issues")
        }

        let multiServiceSuccessCount = serviceResults.filter { $0 }.count
        print("   Multi-service success rate: \(multiServiceSuccessCount)/\(serviceResults.count)")

        print("\n" + String(repeating: "=", count: 70))
        print("🔍 SERVICE STATE INSPECTION COMPLETE")
        print(String(repeating: "=", count: 70) + "\n")
    }
}
