#!/bin/bash

# DTS App Project Health Check Script
# Performs comprehensive health check and provides recommendations

PROJECT_ROOT="/Users/chandlerstaton/Desktop/DTS APP"
cd "$PROJECT_ROOT" || exit 1

HEALTH_SCORE=0
MAX_SCORE=10

echo "🏥 DTS App Project Health Check"
echo "================================"
echo ""

echo "1. Git Repository Status"
echo "------------------------"
if [ -d ".git" ]; then
    echo "✅ Git repository found"

    # Check for uncommitted changes
    if git diff --quiet && git diff --staged --quiet; then
        echo "✅ Clean working directory (+1 point)"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
    else
        echo "⚠️ Uncommitted changes found"
        git status --porcelain
    fi
else
    echo "❌ No git repository found!"
fi

echo ""
echo "2. ContentView.swift Integrity"
echo "-----------------------------"
CONTENT_VIEW="DTS App/DTS App/ContentView.swift"
if [ -f "$CONTENT_VIEW" ]; then
    LINE_COUNT=$(wc -l < "$CONTENT_VIEW")
    echo "📄 ContentView.swift: $LINE_COUNT lines"

    if [ "$LINE_COUNT" -gt 6000 ]; then
        echo "❌ Extremely large file - likely duplicates"
    elif [ "$LINE_COUNT" -gt 3000 ]; then
        echo "✅ Large comprehensive app file ($LINE_COUNT lines) (+2 points)"
        HEALTH_SCORE=$((HEALTH_SCORE + 2))
    else
        echo "✅ Normal size file (+2 points)"
        HEALTH_SCORE=$((HEALTH_SCORE + 2))
    fi

    STRUCT_COUNT=$(grep -c "^struct ContentView:" "$CONTENT_VIEW" || echo "0")
    if [ "$STRUCT_COUNT" -eq 1 ]; then
        echo "✅ Single ContentView declaration (+2 points)"
        HEALTH_SCORE=$((HEALTH_SCORE + 2))
    else
        echo "❌ Found $STRUCT_COUNT ContentView declarations"
    fi
else
    echo "❌ ContentView.swift not found!"
fi

echo ""
echo "3. Backup Files Check"
echo "--------------------"
BACKUP_FILES=$(find "$PROJECT_ROOT" -name "*.bak*" -o -name "*_backup_*" -o -name "*.swift.bak*" 2>/dev/null)
if [ -z "$BACKUP_FILES" ]; then
    echo "✅ No problematic backup files (+1 point)"
    HEALTH_SCORE=$((HEALTH_SCORE + 1))
else
    echo "⚠️ Found backup files that could cause conflicts:"
    echo "$BACKUP_FILES"
fi

echo ""
echo "4. Project Structure"
echo "-------------------"
REQUIRED_DIRS=(
    "DTS App/DTS App"
    "DTS App/DTS App/Models"
    "DTS App/DTS App/Views"
    "DTS App/DTS App/Services"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir exists"
    else
        echo "❌ Missing: $dir"
    fi
done

echo ""
echo "5. Build Test"
echo "------------"
echo "Testing build (this may take a moment)..."
cd "DTS App"
BUILD_OUTPUT=$(xcodebuild -project "DTS App.xcodeproj" -scheme "DTS App" -sdk iphonesimulator build 2>&1)
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ Project builds successfully (+3 points)"
    HEALTH_SCORE=$((HEALTH_SCORE + 3))
else
    echo "❌ Build failed - check for errors"
    echo "$BUILD_OUTPUT" | grep -i error | head -3
fi

cd "$PROJECT_ROOT"

echo ""
echo "6. Git Backup Status"
echo "-------------------"
if [ -d ".git" ]; then
    LATEST_COMMIT=$(git log --oneline -1)
    echo "$LATEST_COMMIT"
    echo "✅ Latest commit available (+1 point)"
    HEALTH_SCORE=$((HEALTH_SCORE + 1))

    if git remote get-url origin >/dev/null 2>&1; then
        echo "✅ GitHub remote configured"

        # Check if up to date with remote
        git fetch origin >/dev/null 2>&1
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

        if [ "$LOCAL" = "$REMOTE" ]; then
            echo "✅ Up to date with GitHub"
        else
            echo "⚠️ Local changes not pushed to GitHub"
        fi
    else
        echo "❌ No GitHub remote configured"
    fi
fi

echo ""
echo "📊 HEALTH REPORT"
echo "================"
echo "Score: $HEALTH_SCORE/$MAX_SCORE"

if [ $HEALTH_SCORE -ge 8 ]; then
    echo "🟢 EXCELLENT: Project is in great shape!"
elif [ $HEALTH_SCORE -ge 6 ]; then
    echo "🟡 GOOD: Project is mostly healthy with minor issues"
elif [ $HEALTH_SCORE -ge 4 ]; then
    echo "🟠 WARNING: Project has issues that need attention"
else
    echo "🔴 CRITICAL: Project needs immediate attention"
fi

echo ""
echo "💡 RECOMMENDATIONS:"
echo "- Run this health check before major changes"
echo "- Always commit working states to git"
echo "- Push to GitHub regularly for backup"
echo "- If health score drops below 6, investigate immediately"
