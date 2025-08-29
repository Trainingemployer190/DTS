#!/bin/bash

echo "🧹 Cleaning up DTS App project clutter..."
echo "This will remove temporary files, logs, and development artifacts while preserving your core project files."
echo ""

# Check if running in a Git hook (non-interactive)
if [ -t 0 ]; then
    # Interactive mode - ask for confirmation
    read -p "Do you want to proceed with cleanup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
else
    # Non-interactive mode (Git hook) - proceed automatically
    echo "Running in non-interactive mode, proceeding with cleanup..."
fi

echo ""
echo "Starting cleanup..."

# Remove development scripts and logs
echo "Removing development scripts and logs..."
rm -f build_result.log
rm -f clean_debug.sh
rm -f discover-ios-config.sh
rm -f fix_script.sh
rm -f health-check.sh
rm -f install_with_url_scheme.sh

# Remove HTML files (GitHub Pages redirect, OAuth redirect)
echo "Removing temporary HTML files..."
rm -f github-pages-redirect.html
rm -f oauth-redirect.html

# Remove backup files
echo "Removing backup files..."
rm -f SettingsView.swift.backup2
rm -f "DTS App/DTS App/ContentView.swift.massive_backup"

# Remove LEGACY_FILES directory
echo "Removing legacy files directory..."
rm -rf LEGACY_FILES/

# Remove documentation files (keep README.md)
echo "Removing development documentation..."
rm -f JOBBER_API_DOCUMENTATION.md
rm -f JOBBER_API_QUICKSTART.md
rm -f JOBBER_API_REFERENCE.md
rm -f SAFETY-GUIDE.md
rm -f SETUP_COMPLETE.md
rm -f TESTFLIGHT_READY.md
rm -f VERIFICATION_REPORT.md

# Clean up Xcode derived data (if exists)
echo "Cleaning Xcode derived data..."
if [ -d ~/Library/Developer/Xcode/DerivedData/DTS_App* ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/DTS_App*
    echo "Removed Xcode derived data"
fi

# Clean up any .DS_Store files
echo "Removing .DS_Store files..."
find . -name ".DS_Store" -type f -delete 2>/dev/null

# Clean up any temporary Swift files
echo "Removing temporary Swift files..."
find . -name "*.tmp" -type f -delete 2>/dev/null
find . -name "*.swiftdeps" -type f -delete 2>/dev/null

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Files preserved:"
echo "  📱 DTS App/ - Your main app source code"
echo "  🔧 DTS App.xcodeproj/ - Xcode project files"
echo "  🧪 DTS AppTests/ - Test files"
echo "  🧪 DTS AppUITests/ - UI test files"
echo "  📋 DTS App.xctestplan & DTS AppTests.xctestplan - Test plans"
echo "  ⚙️  Info.plist - App configuration"
echo "  📝 README.md - Project documentation"
echo "  🎯 .vscode/ - VS Code settings"
echo "  📄 DTS-App.code-workspace - Workspace file"
echo "  🖼️  screenshot.png - Project screenshot"
echo "  🔄 .git/ & .github/ - Git repository"
echo ""
echo "Removed clutter:"
echo "  🗑️  Development scripts (fix_script.sh, health-check.sh, etc.)"
echo "  🗑️  Log files (build_result.log)"
echo "  🗑️  Backup files (*.backup*, ContentView.swift.massive_backup)"
echo "  🗑️  Legacy files directory"
echo "  🗑️  Temporary HTML files"
echo "  🗑️  Development documentation files"
echo "  🗑️  Xcode derived data"
echo ""
echo "Your project is now clean and organized! 🎉"
