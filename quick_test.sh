#!/bin/bash

# Quick Test Runner for RoleCall Bug Replication
# This script runs just our specific tests without all the overhead

echo "🚀 Quick Test Runner for RoleCall"
echo "=================================="

# Function to run a specific test
run_specific_test() {
    local test_name="$1"
    echo ""
    echo "🔍 Running: $test_name"
    echo "----------------------------"

    xcodebuild test \
        -project RoleCall.xcodeproj \
        -scheme RoleCall \
        -destination 'platform=iOS Simulator,name=iPhone 16' \
        -only-testing:"RoleCallTests/BugReplicationTestRunner/$test_name" \
        2>/dev/null | grep -E "(Test case|passed|failed|✅|❌|🐛|📱|🎬|📊|🔍)" || echo "No detailed output available"
}

# Check command line argument
if [ "$1" = "main" ] || [ "$1" = "bug" ]; then
    run_specific_test "replicateCompleteBugScenario"
elif [ "$1" = "rapid" ]; then
    run_specific_test "rapidFireActorTapSimulation"
elif [ "$1" = "inspect" ]; then
    run_specific_test "tmdbServiceStateInspection"
elif [ "$1" = "all" ]; then
    echo "Running all bug replication tests..."
    run_specific_test "replicateCompleteBugScenario"
    run_specific_test "rapidFireActorTapSimulation"
    run_specific_test "tmdbServiceStateInspection"
else
    echo ""
    echo "Usage: ./quick_test.sh [test_type]"
    echo ""
    echo "Available tests:"
    echo "  main/bug  - Run the main bug replication test"
    echo "  rapid     - Run rapid fire actor tap simulation"
    echo "  inspect   - Run service state inspection"
    echo "  all       - Run all bug replication tests"
    echo ""
    echo "Example: ./quick_test.sh main"
    exit 1
fi

echo ""
echo "✅ Quick test run complete!"
