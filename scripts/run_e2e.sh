#!/usr/bin/env bash
# ==============================================================================
# Lifecore Maestro E2E Automated Test Runner
#
# Usage:
#   ./scripts/run_e2e.sh                     # Runs all flows via suite.yaml
#   ./scripts/run_e2e.sh 01_profile...yaml   # Runs a specific flow
#   SIMULATOR="iPhone 18 Pro" ./scripts/run_e2e.sh
# ==============================================================================

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}        Lifecore Maestro E2E Test Suite Runner       ${NC}"
echo -e "${CYAN}=====================================================${NC}"

# 1. Xcode Developer Directory Setup
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    else
        echo -e "${RED}[ERROR] /Applications/Xcode.app not found.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}[✓] Using Xcode Developer Directory:${NC} $DEVELOPER_DIR"

# 1.1 Java 17+ Resolution (Required by Maestro CLI)
if [[ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
elif [[ -d "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
fi

if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    if [[ "$JAVA_VER" == "1" ]]; then
        JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f2)
    fi
    echo -e "${GREEN}[✓] Using Java version:${NC} $JAVA_VER (JAVA_HOME: ${JAVA_HOME:-system default})"
fi

# 2. Simulator Resolution
SIM_NAME="${SIMULATOR:-iPhone 17}"

# Check for already booted device first
BOOTED_ID=$(xcrun simctl list devices | grep -E '\(Booted\)' | head -n 1 | grep -o -E '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' || true)

if [[ -n "$BOOTED_ID" ]]; then
    DEVICE_ID="$BOOTED_ID"
    DEVICE_NAME=$(xcrun simctl list devices | grep "$BOOTED_ID" | head -n 1 | sed 's/^[ \t]*//' | cut -d'(' -f1 | xargs)
    echo -e "${GREEN}[✓] Using currently booted simulator:${NC} $DEVICE_NAME ($DEVICE_ID)"
else
    # Find requested simulator
    DEVICE_ID=$(xcrun simctl list devices available | grep "$SIM_NAME" | head -n 1 | grep -o -E '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' || true)
    if [[ -z "$DEVICE_ID" ]]; then
        echo -e "${YELLOW}[!] Simulator '$SIM_NAME' not found. Falling back to first available iPhone...${NC}"
        DEVICE_ID=$(xcrun simctl list devices available | grep -E 'iPhone' | head -n 1 | grep -o -E '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' || true)
    fi

    if [[ -z "$DEVICE_ID" ]]; then
        echo -e "${RED}[ERROR] No available iPhone simulator found.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[*] Booting simulator ($DEVICE_ID)...${NC}"
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
    echo -e "${GREEN}[✓] Simulator booted successfully.${NC}"
fi

# 3. Compile Lifecore for Simulator
echo -e "${YELLOW}[*] Building Lifecore for iOS Simulator...${NC}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="$PROJECT_ROOT/ios/Lifecore/Lifecore/Lifecore.xcodeproj"
DERIVED_DATA_DIR="$PROJECT_ROOT/ios/Lifecore/build"

xcodebuild -project "$XCODE_PROJECT" \
           -scheme Lifecore \
           -destination "id=$DEVICE_ID" \
           -configuration Debug \
           -derivedDataPath "$DERIVED_DATA_DIR" \
           build CODE_SIGNING_ALLOWED=NO -quiet

APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/Lifecore.app"

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo -e "${RED}[ERROR] Built app bundle not found at: $APP_BUNDLE${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Build succeeded:${NC} $APP_BUNDLE"

# 4. Install App onto Simulator & Enforce Isolated Fixture Mode
echo -e "${YELLOW}[*] Installing Lifecore.app onto simulator...${NC}"
xcrun simctl install "$DEVICE_ID" "$APP_BUNDLE"
echo -e "${GREEN}[✓] Installed com.skycherepanya.Lifecore${NC}"

# Reset previous E2E fixture database for a deterministic suite run while keeping UserDefaults flags
E2E_CONTAINER_DATA=$(xcrun simctl get_app_container "$DEVICE_ID" com.skycherepanya.Lifecore data 2>/dev/null || true)
if [[ -n "$E2E_CONTAINER_DATA" ]]; then
    rm -f "$E2E_CONTAINER_DATA/Library/Application Support/LifecoreFixtureE2E.store"* || true
fi

xcrun simctl spawn "$DEVICE_ID" defaults delete com.skycherepanya.Lifecore >/dev/null 2>&1 || true
xcrun simctl spawn "$DEVICE_ID" defaults write com.skycherepanya.Lifecore LifecoreFixtureMode -bool true
xcrun simctl spawn "$DEVICE_ID" defaults write com.skycherepanya.Lifecore LifecoreFixtureScenario -string "${LIFECORE_FIXTURE_SCENARIO:-seeded}"
echo -e "${GREEN}[✓] Enforced isolated fixture mode (LifecoreFixtureMode=true, scenario=${LIFECORE_FIXTURE_SCENARIO:-seeded})${NC}"

# 5. Resolve Maestro CLI
MAESTRO_BIN=""
if command -v maestro &> /dev/null; then
    MAESTRO_BIN="$(command -v maestro)"
elif [[ -x "$HOME/.maestro/bin/maestro" ]]; then
    MAESTRO_BIN="$HOME/.maestro/bin/maestro"
fi

if [[ -z "$MAESTRO_BIN" ]]; then
    echo -e "${RED}=====================================================${NC}"
    echo -e "${RED}[ERROR] Maestro CLI is required but not installed.${NC}"
    echo -e "${YELLOW}To install Maestro, run the following command in terminal:${NC}"
    echo -e "${CYAN}  curl -fsSL \"https://get.maestro.mobile.dev\" | bash${NC}"
    echo -e "${YELLOW}Then add it to your PATH:${NC}"
    echo -e "${CYAN}  export PATH=\"\$PATH:\$HOME/.maestro/bin\"${NC}"
    echo -e "${RED}=====================================================${NC}"
    exit 1
fi

# 6. Execute Maestro Flows with Failure Artifact Preservation
TEST_TARGET="${1:-.maestro/suite.yaml}"
if [[ ! -f "$TEST_TARGET" && -f ".maestro/$TEST_TARGET" ]]; then
    TEST_TARGET=".maestro/$TEST_TARGET"
fi

E2E_ARTIFACTS_DIR="${E2E_ARTIFACTS_DIR:-/tmp/lifecore-e2e-artifacts}"
mkdir -p "$E2E_ARTIFACTS_DIR"

on_e2e_failure() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}[!] E2E failed (exit $exit_code). Capturing failure screenshot to $E2E_ARTIFACTS_DIR/failure_screen.png...${NC}"
        xcrun simctl io "$DEVICE_ID" screenshot "$E2E_ARTIFACTS_DIR/failure_screen.png" 2>/dev/null || true
    fi
}
trap on_e2e_failure EXIT

echo -e "${CYAN}[*] Running Maestro test: $TEST_TARGET (artifacts: $E2E_ARTIFACTS_DIR)${NC}"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
"$MAESTRO_BIN" test --debug-output "$E2E_ARTIFACTS_DIR" "$TEST_TARGET"

echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}         All Maestro E2E Tests Succeeded!            ${NC}"
echo -e "${GREEN}=====================================================${NC}"
