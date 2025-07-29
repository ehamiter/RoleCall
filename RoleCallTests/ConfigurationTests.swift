//
//  ConfigurationTests.swift
//  RoleCallTests
//
//  Created by GitHub Copilot on 7/29/25.
//

import Testing
import Foundation
@testable import RoleCall

/// Test suite for configuration-related issues that might cause the first-tap bug
struct ConfigurationTests {

    // MARK: - Configuration Loading Tests

    @Test("Configuration service singleton behavior")
    func testConfigurationServiceSingleton() async throws {
        print("🔍 Testing configuration service singleton behavior...")

        // Get multiple references to the shared instance
        let config1 = ConfigurationService.shared
        let config2 = ConfigurationService.shared

        // Verify they're the same instance
        #expect(config1 === config2, "Configuration service should be a singleton")

        // Test configuration values
        let tmdbToken1 = config1.tmdbAccessToken
        let tmdbToken2 = config2.tmdbAccessToken

        print("Config 1 TMDB Token present: \(tmdbToken1 != nil && !tmdbToken1!.isEmpty)")
        print("Config 2 TMDB Token present: \(tmdbToken2 != nil && !tmdbToken2!.isEmpty)")

        #expect(tmdbToken1 == tmdbToken2, "Configuration values should be consistent")
    }

    @Test("Configuration loading timing")
    func testConfigurationLoadingTiming() async throws {
        print("🔍 Testing configuration loading timing...")

        // Test immediate access
        let startTime = CFAbsoluteTimeGetCurrent()
        let config = ConfigurationService.shared
        let immediateLoadTime = CFAbsoluteTimeGetCurrent() - startTime

        print("Configuration loading time: \(immediateLoadTime * 1000) ms")

        // Test values immediately
        let immediateToken = config.tmdbAccessToken
        let immediateBaseURL = config.tmdbBaseURL

        print("Immediate access results:")
        print("  Token present: \(immediateToken != nil && !immediateToken!.isEmpty)")
        print("  Base URL: \(immediateBaseURL ?? "nil")")

        // Wait a bit and test again
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let delayedToken = config.tmdbAccessToken
        let delayedBaseURL = config.tmdbBaseURL

        print("Delayed access results:")
        print("  Token present: \(delayedToken != nil && !delayedToken!.isEmpty)")
        print("  Base URL: \(delayedBaseURL ?? "nil")")

        // Values should be consistent
        #expect(immediateToken == delayedToken, "Token should be consistent")
        #expect(immediateBaseURL == delayedBaseURL, "Base URL should be consistent")
    }

    @Test("Configuration values validation")
    func testConfigurationValuesValidation() async throws {
        print("🔍 Testing configuration values validation...")

        let config = ConfigurationService.shared

        // Test all TMDB-related configuration values
        let tmdbToken = config.tmdbAccessToken
        let tmdbBaseURL = config.tmdbBaseURL
        let tmdbImageBaseURL = config.tmdbImageBaseURL

        print("Configuration values:")
        print("  TMDB Token: \(tmdbToken != nil ? "Present (\(tmdbToken!.count) chars)" : "Missing")")
        print("  TMDB Base URL: \(tmdbBaseURL ?? "Missing")")
        print("  TMDB Image Base URL: \(tmdbImageBaseURL ?? "Missing")")

        // Validate required values
        #expect(tmdbToken != nil, "TMDB access token must be configured")
        #expect(!tmdbToken!.isEmpty, "TMDB access token must not be empty")
        #expect(tmdbBaseURL != nil, "TMDB base URL must be configured")
        #expect(tmdbImageBaseURL != nil, "TMDB image base URL must be configured")

        // Validate URL formats
        if let baseURL = tmdbBaseURL {
            #expect(baseURL.hasPrefix("https://"), "TMDB base URL should use HTTPS")
            #expect(URL(string: baseURL) != nil, "TMDB base URL should be a valid URL")
        }

        if let imageBaseURL = tmdbImageBaseURL {
            #expect(imageBaseURL.hasPrefix("https://"), "TMDB image base URL should use HTTPS")
            #expect(URL(string: imageBaseURL) != nil, "TMDB image base URL should be a valid URL")
        }

        // Validate token format (TMDB tokens are typically long strings)
        if let token = tmdbToken {
            #expect(token.count > 50, "TMDB access token should be reasonably long")
            #expect(!token.contains(" "), "TMDB access token should not contain spaces")
        }
    }

    // MARK: - Configuration Integration Tests

    @Test("Configuration to service integration timing")
    func testConfigurationToServiceIntegrationTiming() async throws {
        print("🔍 Testing configuration to service integration timing...")

        // Create multiple services in quick succession to test for timing issues
        var services: [TMDBService] = []
        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 1...3 {
            let service = await TMDBService()
            services.append(service)
            print("Service \(i) created at \((CFAbsoluteTimeGetCurrent() - startTime) * 1000) ms")
        }

        // Test each service with a simple request
        for (index, service) in services.enumerated() {
            print("\n--- Testing service \(index + 1) ---")

            do {
                let searchResponse = try await service.searchPerson(name: "Test Actor")
                print("✅ Service \(index + 1) search succeeded: \(searchResponse.results.count) results")
            } catch let error as TMDBError {
                if case .missingConfiguration(let message) = error {
                    print("❌ Service \(index + 1) configuration error: \(message)")

                    // This indicates a timing issue in service initialization
                    if index == 0 {
                        print("🐛 POTENTIAL BUG: First service has configuration issue")
                    }
                } else {
                    print("❌ Service \(index + 1) other error: \(error)")
                }
            } catch {
                print("❌ Service \(index + 1) unexpected error: \(error)")
            }
        }
    }

    @Test("Service configuration state inspection")
    func testServiceConfigurationStateInspection() async throws {
        print("🔍 Testing service configuration state inspection...")

        // Create a service and try to determine its configuration state
        let tmdbService = await TMDBService()

        // Test immediate configuration by making a request
        print("Testing immediate configuration...")

        var immediateConfigOK = false
        do {
            let _ = try await tmdbService.searchPerson(name: "Quick Test")
            immediateConfigOK = true
            print("✅ Immediate configuration appears OK")
        } catch let error as TMDBError {
            if case .missingConfiguration(_) = error {
                print("❌ Immediate configuration missing")
            } else {
                print("❌ Immediate request failed with other error: \(error)")
            }
        }

        // Wait and test again
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        print("Testing delayed configuration...")
        var delayedConfigOK = false
        do {
            let _ = try await tmdbService.searchPerson(name: "Delayed Test")
            delayedConfigOK = true
            print("✅ Delayed configuration appears OK")
        } catch let error as TMDBError {
            if case .missingConfiguration(_) = error {
                print("❌ Delayed configuration still missing")
            } else {
                print("❌ Delayed request failed with other error: \(error)")
            }
        }

        // Analyze the pattern
        if !immediateConfigOK && delayedConfigOK {
            print("🐛 BUG PATTERN DETECTED: Configuration becomes available after delay")
        } else if immediateConfigOK && delayedConfigOK {
            print("✅ Configuration consistently available")
        } else if !immediateConfigOK && !delayedConfigOK {
            print("⚠️ Configuration consistently unavailable - check Config.plist")
        }
    }

    @Test("Multiple service instances configuration consistency")
    func testMultipleServiceInstancesConfigurationConsistency() async throws {
        print("🔍 Testing multiple service instances configuration consistency...")

        // Create services with small delays between them
        var services: [TMDBService] = []

        for i in 1...3 {
            let service = await TMDBService()
            services.append(service)
            print("Created service \(i)")

            // Small delay between creations
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }

        // Test all services concurrently
        await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, service) in services.enumerated() {
                group.addTask {
                    do {
                        let _ = try await service.searchPerson(name: "Concurrent Test")
                        return (index + 1, true)
                    } catch {
                        return (index + 1, false)
                    }
                }
            }

            var results: [(Int, Bool)] = []
            for await result in group {
                results.append(result)
            }

            results.sort { $0.0 < $1.0 }

            print("Service configuration results:")
            for (serviceNum, success) in results {
                print("  Service \(serviceNum): \(success ? "✅ OK" : "❌ Failed")")
            }

            let successCount = results.filter { $0.1 }.count
            let failureCount = results.count - successCount

            if failureCount > 0 {
                print("⚠️ \(failureCount) out of \(results.count) services failed configuration")
            } else {
                print("✅ All services configured successfully")
            }
        }
    }
}
