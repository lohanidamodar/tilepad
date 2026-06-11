#!/bin/bash

# Tilepad Quick Start Script
# This script helps users get started with Tilepad quickly

echo "🚀 Tilepad Quick Start"
echo "========================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Check if Flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        echo ""
        echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
        echo "Then add Flutter to your PATH and run this script again."
        exit 1
    fi
    
    local flutter_version=$(flutter --version | head -n 1)
    print_status "Flutter found: $flutter_version"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "pubspec.yaml" ]; then
        print_error "pubspec.yaml not found"
        echo "Please run this script from the Tilepad project root directory."
        exit 1
    fi
    
    if ! grep -q "tilepad" pubspec.yaml; then
        print_warning "This doesn't appear to be the Tilepad project"
        echo "Are you sure you're in the right directory? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_status "Project directory verified"
}

# Install dependencies
install_dependencies() {
    print_info "Installing Flutter dependencies..."
    if flutter pub get; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Run Flutter doctor
run_flutter_doctor() {
    print_info "Running Flutter doctor to check setup..."
    flutter doctor
    echo ""
    print_info "If you see any issues above, please resolve them before continuing."
    echo "Press any key to continue..."
    read -n 1 -s
}

# Show available platforms
show_platforms() {
    echo ""
    print_info "Available platforms for Tilepad:"
    echo ""
    echo "📱 Mobile Platforms (Client):"
    echo "   • Android - Run: flutter run -d android"
    echo "   • iOS - Run: flutter run -d ios (macOS only)"
    echo ""
    echo "🖥️ Desktop Platforms (Server):"
    echo "   • Windows - Run: flutter run -d windows"
    echo "   • macOS - Run: flutter run -d macos"
    echo "   • Linux - Run: flutter run -d linux"
    echo ""
    echo "🌐 Web Platform (Client):"
    echo "   • Chrome - Run: flutter run -d chrome"
    echo ""
}

# Interactive platform selection
select_platform() {
    echo "Which platform would you like to run? (or 'q' to quit)"
    echo "1) Android (Client)"
    echo "2) iOS (Client) - macOS only"
    echo "3) Windows (Server)"
    echo "4) macOS (Server)"
    echo "5) Linux (Server)"
    echo "6) Web (Client)"
    echo "7) List available devices"
    echo "8) Build verification test"
    echo ""
    read -p "Enter your choice (1-8 or q): " choice
    
    case $choice in
        1)
            print_info "Starting Android client..."
            flutter run -d android
            ;;
        2)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                print_info "Starting iOS client..."
                flutter run -d ios
            else
                print_error "iOS development is only supported on macOS"
            fi
            ;;
        3)
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
                print_info "Starting Windows server..."
                flutter run -d windows
            else
                print_error "Windows builds are only supported on Windows"
            fi
            ;;
        4)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                print_info "Starting macOS server..."
                flutter run -d macos
            else
                print_error "macOS builds are only supported on macOS"
            fi
            ;;
        5)
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                print_info "Starting Linux server..."
                flutter run -d linux
            else
                print_error "Linux builds are only supported on Linux"
            fi
            ;;
        6)
            print_info "Starting web client..."
            flutter run -d chrome
            ;;
        7)
            print_info "Available devices:"
            flutter devices
            echo ""
            select_platform
            ;;
        8)
            if [ -f "build_verification.sh" ]; then
                print_info "Running build verification..."
                chmod +x build_verification.sh
                ./build_verification.sh
            else
                print_error "Build verification script not found"
            fi
            ;;
        q|Q)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please enter 1-8 or q."
            select_platform
            ;;
    esac
}

# Show usage instructions
show_usage() {
    echo ""
    print_info "Quick Usage Guide:"
    echo ""
    echo "🖥️ Server Setup (Desktop):"
    echo "   1. Run the server on your desktop computer"
    echo "   2. Click 'Start Server' in the application"
    echo "   3. Note the connection URL (e.g., ws://192.168.1.100:8080)"
    echo "   4. Create your macro buttons using the button editor"
    echo ""
    echo "📱 Client Setup (Mobile/Web):"
    echo "   1. Run the client on your mobile device or web browser"
    echo "   2. Add the server using the connection URL from step 3 above"
    echo "   3. Connect to the server"
    echo "   4. Your macro buttons will appear automatically"
    echo ""
    echo "📚 For more information:"
    echo "   • README.md - Complete documentation"
    echo "   • CONTRIBUTING.md - Development guidelines"
    echo "   • CHANGELOG.md - Recent changes and features"
    echo ""
}

# Main script execution
main() {
    print_info "Welcome to Tilepad - Remote Macro Control"
    echo ""
    
    check_flutter
    check_directory
    install_dependencies
    
    # Ask if user wants to run Flutter doctor
    echo ""
    echo "Would you like to run Flutter doctor to check your setup? (Y/n)"
    read -r response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        print_info "Skipping Flutter doctor check"
    else
        run_flutter_doctor
    fi
    
    show_platforms
    show_usage
    
    echo ""
    select_platform
}

# Run the main function
main "$@"