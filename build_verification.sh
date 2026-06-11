#!/bin/bash

# Tilepad Build Verification Script
# This script attempts to verify the build process for different platforms

echo "🚀 Tilepad Build Verification Script"
echo "======================================="

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "   Please install Flutter SDK from https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"

# Get current directory
PROJECT_DIR=$(pwd)
echo "📁 Project directory: $PROJECT_DIR"

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml not found. Please run this script from the Flutter project root."
    exit 1
fi

echo "✅ Flutter project detected"

# Function to check platform support
check_platform_support() {
    local platform=$1
    echo "🔍 Checking $platform support..."
    
    if flutter devices | grep -q "$platform"; then
        echo "✅ $platform support detected"
        return 0
    else
        echo "⚠️  $platform support not available"
        return 1
    fi
}

# Function to attempt build
attempt_build() {
    local platform=$1
    local target=$2
    echo "🛠️  Attempting to build for $platform ($target)..."
    
    # Create output directory
    mkdir -p build_outputs
    
    # Attempt build
    if flutter build $target --verbose > "build_outputs/${platform}_build.log" 2>&1; then
        echo "✅ $platform build successful"
        return 0
    else
        echo "❌ $platform build failed"
        echo "   Check build_outputs/${platform}_build.log for details"
        return 1
    fi
}

# Run flutter doctor
echo "🏥 Running Flutter doctor..."
flutter doctor > build_outputs/flutter_doctor.log 2>&1
if grep -q "No issues found" build_outputs/flutter_doctor.log; then
    echo "✅ Flutter doctor: No issues found"
else
    echo "⚠️  Flutter doctor found some issues"
    echo "   Check build_outputs/flutter_doctor.log for details"
fi

# Clean and get dependencies
echo "🧹 Cleaning project and getting dependencies..."
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null 2>&1

# Check for analysis issues
echo "🔍 Running Flutter analyze..."
if flutter analyze > build_outputs/analyze.log 2>&1; then
    echo "✅ Static analysis passed"
else
    echo "⚠️  Static analysis found issues"
    echo "   Check build_outputs/analyze.log for details"
fi

# Platform-specific build tests
declare -A builds
builds["Android"]="apk"
builds["iOS"]="ios --no-codesign"
builds["Web"]="web"
builds["Windows"]="windows"
builds["macOS"]="macos"
builds["Linux"]="linux"

successful_builds=0
total_builds=0

for platform in "${!builds[@]}"; do
    target=${builds[$platform]}
    total_builds=$((total_builds + 1))
    
    # Check if platform is supported
    case $platform in
        "Android")
            if command -v adb &> /dev/null || [ -n "$ANDROID_HOME" ]; then
                if attempt_build "$platform" "$target"; then
                    successful_builds=$((successful_builds + 1))
                fi
            else
                echo "⚠️  Android SDK not found, skipping Android build"
            fi
            ;;
        "iOS")
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if attempt_build "$platform" "$target"; then
                    successful_builds=$((successful_builds + 1))
                fi
            else
                echo "⚠️  iOS builds only supported on macOS, skipping"
            fi
            ;;
        "Web")
            if attempt_build "$platform" "$target"; then
                successful_builds=$((successful_builds + 1))
            fi
            ;;
        "Windows")
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
                if attempt_build "$platform" "$target"; then
                    successful_builds=$((successful_builds + 1))
                fi
            else
                echo "⚠️  Windows builds only supported on Windows, skipping"
            fi
            ;;
        "macOS")
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if attempt_build "$platform" "$target"; then
                    successful_builds=$((successful_builds + 1))
                fi
            else
                echo "⚠️  macOS builds only supported on macOS, skipping"
            fi
            ;;
        "Linux")
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                if attempt_build "$platform" "$target"; then
                    successful_builds=$((successful_builds + 1))
                fi
            else
                echo "⚠️  Linux builds only supported on Linux, skipping"
            fi
            ;;
    esac
done

# Summary
echo ""
echo "📊 Build Summary"
echo "================"
echo "Successful builds: $successful_builds"
echo "Total attempted: $total_builds"

if [ $successful_builds -gt 0 ]; then
    echo "✅ At least one platform build succeeded"
    exit 0
else
    echo "❌ All attempted builds failed"
    echo "   Check individual log files in build_outputs/ for details"
    exit 1
fi