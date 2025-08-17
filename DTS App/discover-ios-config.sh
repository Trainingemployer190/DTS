#!/bin/bash

# iOS Development Discovery Script
# Helps you find the correct PROJECT_PATH, SCHEME_NAME, and SIMULATOR_NAME

set -e

PROJECT_PATH="DTS App/DTS App.xcodeproj"

echo "🔍 iOS Development Environment Discovery"
echo "========================================"
echo ""

# Check if Xcode is properly set up
echo "📱 Checking Xcode setup..."
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: xcodebuild not found. Make sure Xcode is installed and xcode-select is configured."
    echo "   Run: sudo xcode-select --install"
    exit 1
fi

XCODE_PATH=$(xcode-select -p)
echo "✅ Xcode found at: $XCODE_PATH"
echo ""

# Verify project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Error: Project not found at $PROJECT_PATH"
    echo "   Please verify the project path is correct."
    exit 1
fi

echo "✅ Project found at: $PROJECT_PATH"
echo ""

# List available schemes
echo "📋 Available Schemes:"
echo "===================="
xcodebuild -list -project "$PROJECT_PATH" 2>/dev/null | awk '/Schemes:/{flag=1;next}/Build Configurations:/{flag=0}flag' | grep -v '^$' | sed 's/^[[:space:]]*/  • /'
echo ""

# List available simulators
echo "📱 Available iOS Simulators:"
echo "============================"
xcrun simctl list devices | grep -E "iPhone|iPad" | grep -v "unavailable" | sed 's/^[[:space:]]*/  • /' | head -10
echo ""

# Check signing team
echo "🔐 Checking Code Signing:"
echo "========================="
PLIST_PATH="$PROJECT_PATH/project.pbxproj"
if grep -q "DEVELOPMENT_TEAM = WNU63L8T28" "$PLIST_PATH"; then
    echo "✅ Development team is configured: WNU63L8T28"
else
    echo "⚠️  Development team may need configuration"
    echo "   If you encounter signing errors:"
    echo "   1. Open project in Xcode: open '$PROJECT_PATH'"
    echo "   2. Select your project in the navigator"
    echo "   3. Go to Signing & Capabilities tab"
    echo "   4. Select your Team under Signing"
fi
echo ""

# Usage instructions
echo "🚀 Usage Instructions:"
echo "======================"
echo "1. Update the variables in .vscode/tasks.json inputs if needed:"
echo "   • PROJECT_PATH: $PROJECT_PATH"
echo "   • SCHEME_NAME: Choose from schemes listed above"
echo "   • SIMULATOR_NAME: Choose from simulators listed above"
echo ""
echo "2. In VS Code, use Command Palette (Cmd+Shift+P):"
echo "   • 'Tasks: Run Build Task' or Cmd+Shift+B to build"
echo "   • 'Tasks: Run Task' → 'Run on Simulator' to run"
echo ""
echo "3. Or use the status bar buttons for quick access"
echo ""

echo "✨ Setup complete! Happy coding in VS Code with iOS development!"
