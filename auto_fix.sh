#!/bin/bash
# ============================================================
#  AP_NOTES AUTO-FIX SCRIPT
#  File: auto_fix.sh
#  Place this file in: AP_NOTES-main/   (root of the project)
#  Run with: bash auto_fix.sh
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "============================================"
echo "   AP NOTES - Auto Fix & Build Script"
echo "============================================"
echo ""

# ---- Step 1: Check Flutter is installed ----
echo "[1/7] Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
  echo -e "${RED}ERROR: Flutter not found. Please install Flutter from https://flutter.dev/docs/get-started/install${NC}"
  exit 1
fi
echo -e "${GREEN}Flutter found: $(flutter --version | head -1)${NC}"

# ---- Step 2: Clean previous build ----
echo ""
echo "[2/7] Cleaning previous build..."
flutter clean
echo -e "${GREEN}Clean done.${NC}"

# ---- Step 3: Get dependencies ----
echo ""
echo "[3/7] Getting dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR: pub get failed. Check pubspec.yaml${NC}"
  exit 1
fi
echo -e "${GREEN}Dependencies resolved.${NC}"

# ---- Step 4: Run dart fix (auto-fixes common Dart issues) ----
echo ""
echo "[4/7] Running dart fix --apply (auto-corrects code issues)..."
dart fix --apply
echo -e "${GREEN}Dart fix applied.${NC}"

# ---- Step 5: Analyze for remaining errors ----
echo ""
echo "[5/7] Analyzing code for errors..."
ANALYZE_OUTPUT=$(flutter analyze 2>&1)
echo "$ANALYZE_OUTPUT"

if echo "$ANALYZE_OUTPUT" | grep -q "error •"; then
  echo ""
  echo -e "${YELLOW}⚠ Errors found above. Attempting known automatic fixes...${NC}"

  # Fix 1: WillPopScope -> PopScope (Flutter 3.12+)
  echo "  → Fixing deprecated WillPopScope..."
  find lib -name "*.dart" -exec sed -i \
    's/WillPopScope(/PopScope(canPop: false, /g' {} \;
  find lib -name "*.dart" -exec sed -i \
    's/onWillPop: /onPopInvoked: (bool didPop) async { if (didPop) return; /g' {} \;

  # Fix 2: withOpacity deprecated -> withValues
  echo "  → Fixing .withOpacity() deprecation..."
  find lib -name "*.dart" -exec sed -i \
    's/\.withOpacity(\([^)]*\))/\.withValues(alpha: \1)/g' {} \;

  # Fix 3: Remove const from non-const constructors
  echo "  → Running dart fix again after patches..."
  dart fix --apply

  echo ""
  echo "[5b/7] Re-analyzing after fixes..."
  flutter analyze 2>&1
else
  echo -e "${GREEN}No errors found! Code is clean.${NC}"
fi

# ---- Step 6: Build APK ----
echo ""
echo "[6/7] Building release APK..."
flutter build apk --release

if [ $? -ne 0 ]; then
  echo ""
  echo -e "${RED}Build FAILED. Check errors above.${NC}"
  echo ""
  echo "Common fixes:"
  echo "  • Run: flutter doctor -v  (check your setup)"
  echo "  • Check android/app/build.gradle minSdkVersion (use 21)"
  echo "  • Check pubspec.yaml for version conflicts"
  exit 1
fi

# ---- Step 7: Done ----
echo ""
echo "============================================"
echo -e "${GREEN}✅  BUILD SUCCESSFUL!${NC}"
echo "============================================"
echo ""
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
  SIZE=$(du -sh "$APK_PATH" | cut -f1)
  echo -e "APK Location : ${GREEN}$APK_PATH${NC}"
  echo -e "APK Size     : ${GREEN}$SIZE${NC}"
fi
echo ""
echo "Install on device:  flutter install"
echo "Or copy the APK to your phone and install manually."
echo ""
