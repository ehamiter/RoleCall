# RoleCall Testing Framework for Actor Detail Loading Bug

## Overview

This testing framework has been created to help debug and replicate the actor detail loading bug you described:

> App opens → connects → shows cast list → user taps on a cast member → sheet opens with error message (blank query sent to TMDB API) → user dismisses sheet → user taps another cast member → this time it works as expected.

## Test Structure

The testing framework consists of several test files:

### 1. `BugReplicationTestRunner.swift`
**Main test file that replicates the exact bug scenario**

- `replicateCompleteBugScenario()` - The primary test that simulates the full app startup and user interaction pattern
- `rapidFireActorTapSimulation()` - Tests rapid successive actor taps
- `tmdbServiceStateInspection()` - Analyzes service initialization timing

### 2. `TMDBServiceTests.swift`
**Tests focused on the TMDB service initialization and behavior**

- Configuration loading tests
- Service initialization timing tests
- Sequential actor search tests
- Empty/invalid actor name handling
- Concurrent service initialization tests

### 3. `ActorDetailViewTests.swift`
**Tests that focus on the ActorDetailView scenario**

- First tap failure scenario replication
- Actor detail loading with invalid names
- Rapid successive actor detail requests
- Configuration state testing
- Actor loading with retry mechanism

### 4. `ConfigurationTests.swift`
**Tests focused on configuration loading and timing issues**

- Configuration service singleton behavior
- Configuration loading timing
- Configuration values validation
- Configuration to service integration timing
- Multiple service instances consistency

## How to Run the Tests

### Run All Tests
```bash
cd /Users/eric/projects/xcode-projects/RoleCall
xcodebuild test -project RoleCall.xcodeproj -scheme RoleCall -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Run Specific Test Categories

**Bug Replication Tests:**
```bash
xcodebuild test -project RoleCall.xcodeproj -scheme RoleCall -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing RoleCallTests/BugReplicationTestRunner
```

**TMDB Service Tests:**
```bash
xcodebuild test -project RoleCall.xcodeproj -scheme RoleCall -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing RoleCallTests/TMDBServiceTests
```

**Actor Detail View Tests:**
```bash
xcodebuild test -project RoleCall.xcodeproj -scheme RoleCall -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing RoleCallTests/ActorDetailViewTests
```

**Configuration Tests:**
```bash
xcodebuild test -project RoleCall.xcodeproj -scheme RoleCall -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing RoleCallTests/ConfigurationTests
```

### Run Individual Tests

**Main Bug Replication Test:**
```bash
xcodebuild test -project RoleCall.xcodeproj -scheme RoleCall -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing RoleCallTests/BugReplicationTestRunner/replicateCompleteBugScenario
```

## Understanding Test Output

The tests provide detailed logging to help identify the timing and nature of the bug:

### Successful Bug Replication
If the bug is replicated, you'll see output like:
```
🐛 BUG CONFIRMED!
First tap failed, second tap succeeded
This matches the exact bug report scenario
Root cause: Configuration timing issue
```

### No Bug Detected
If the bug doesn't occur, you'll see:
```
✅ No bug detected - both taps worked
Either bug is fixed or configuration was ready immediately
```

### Configuration Issues
If there are persistent configuration problems:
```
⚠️ Both taps failed - likely configuration issue
Check Config.plist file
```

## Expected Behavior Analysis

Based on the code analysis, the likely root cause of the bug is:

1. **Service Initialization Timing**: The `TMDBService` is marked with `@MainActor` and has async initialization
2. **Configuration Loading Delay**: There may be a race condition between when the service is created and when the configuration is fully loaded
3. **First Request Failure**: The first actor tap might happen before the TMDB access token is properly loaded
4. **Subsequent Success**: By the time of the second tap, the configuration has been loaded

## Key Test Functions

### `replicateCompleteBugScenario()`
This test:
1. Simulates app startup by creating ConfigurationService and TMDBService
2. Immediately tries to load actor data (simulating first tap)
3. Waits 2 seconds (simulating user dismissing error and waiting)
4. Tries to load actor data again (simulating second tap)
5. Analyzes the pattern and reports findings

### Configuration Validation
The tests also validate:
- TMDB access token presence and format
- Configuration consistency across service instances
- Service initialization timing
- URL validation for API endpoints

## Debugging Workflow

1. **Run the main bug replication test** to see if you can reproduce the issue
2. **Check configuration tests** if you see persistent failures
3. **Run TMDB service tests** to analyze initialization timing
4. **Review test output logs** for detailed timing and error information

## Files Created

The testing framework adds these files to your project:

- `RoleCallTests/TMDBServiceTests.swift`
- `RoleCallTests/ActorDetailViewTests.swift`
- `RoleCallTests/ConfigurationTests.swift`
- `RoleCallTests/BugReplicationTestRunner.swift`

The original `RoleCallTests.swift` was also updated to include Foundation import.

## Next Steps

1. Run the tests to see if they can replicate your bug
2. Analyze the test output to understand the timing and configuration issues
3. Use the detailed logging to identify exactly when and why the first request fails
4. Once you identify the root cause, you can implement fixes and use these tests to verify the solution

The tests are designed to be comprehensive and provide detailed insights into the service initialization and configuration loading process that's likely causing your actor detail loading bug.
