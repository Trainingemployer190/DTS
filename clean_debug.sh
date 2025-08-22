#!/bin/bash

# Script to wrap print statements with DEBUG flags for production

echo "Cleaning up debug prints in JobberAPI.swift..."

# Replace all print statements with DEBUG-wrapped versions
sed -i '.bak' 's/^[[:space:]]*print(/            #if DEBUG\n            print(/g' "/Users/chandlerstaton/Desktop/DTS APP/DTS App/DTS App/Managers/JobberAPI.swift"
sed -i '' 's/print(\(.*\))$/print(\1)\n            #endif/g' "/Users/chandlerstaton/Desktop/DTS APP/DTS App/DTS App/Managers/JobberAPI.swift"

echo "Debug cleanup complete!"
