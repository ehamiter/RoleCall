#!/usr/bin/env swift

import Foundation

// Simple debug test runner that mimics our bug replication test
// This runs directly without Xcode overhead and shows all output

print("🚀 RoleCall Bug Debug Test")
print("=========================")
print("Running simplified version of bug replication test...")
print("")

// Mock the timing issue that we suspect
print("📱 PHASE 1: Simulating app startup...")
let startTime = CFAbsoluteTimeGetCurrent()

// Simulate configuration loading delay
Thread.sleep(forTimeInterval: 0.1) // 100ms delay to simulate config loading

let initTime = CFAbsoluteTimeGetCurrent() - startTime
print("   App initialization took: \(initTime * 1000) ms")

print("")
print("🎬 PHASE 2: Simulating first tap (immediate after startup)...")
let firstTapTime = CFAbsoluteTimeGetCurrent()

// Simulate the first tap failing due to configuration not ready
let configReady = initTime > 0.05 // Config ready if init took more than 50ms
let firstTapSucceeded = configReady

let firstTapDuration = CFAbsoluteTimeGetCurrent() - firstTapTime

if firstTapSucceeded {
    print("   ✅ FIRST TAP SUCCEEDED")
    print("   Duration: \(firstTapDuration * 1000) ms")
} else {
    print("   ❌ FIRST TAP FAILED (configuration not ready)")
    print("   Duration: \(firstTapDuration * 1000) ms")
    print("   Error: Configuration loading still in progress")
}

print("")
print("🎬 PHASE 3: Simulating second tap (after delay)...")

// Simulate user dismissing error and tapping again
Thread.sleep(forTimeInterval: 2.0) // 2 second delay

let secondTapTime = CFAbsoluteTimeGetCurrent()

// By now, configuration should definitely be ready
let secondTapSucceeded = true
let secondTapDuration = CFAbsoluteTimeGetCurrent() - secondTapTime

if secondTapSucceeded {
    print("   ✅ SECOND TAP SUCCEEDED")
    print("   Duration: \(secondTapDuration * 1000) ms")
} else {
    print("   ❌ SECOND TAP FAILED")
    print("   Duration: \(secondTapDuration * 1000) ms")
}

print("")
print("📊 PHASE 4: Bug analysis...")

if !firstTapSucceeded && secondTapSucceeded {
    print("   🐛 BUG CONFIRMED!")
    print("   First tap failed, second tap succeeded")
    print("   Root cause: Configuration timing issue")
    print("   - App startup and configuration loading race condition")
    print("   - First user interaction happens before config is ready")
    print("   - Subsequent interactions work because config is loaded")
} else if firstTapSucceeded && secondTapSucceeded {
    print("   ✅ No bug detected - both taps worked")
    print("   Configuration was ready immediately")
} else {
    print("   ⚠️ Unexpected pattern detected")
}

print("")
print("🔧 RECOMMENDED FIXES:")
print("   1. Add proper loading state in TMDBService")
print("   2. Queue requests until configuration is ready")
print("   3. Show loading indicator during initial configuration")
print("   4. Add retry mechanism for failed requests")

print("")
print("✅ Debug test complete!")
print("=========================")
