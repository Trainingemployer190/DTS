#!/bin/bash
content_file="DTS App/DTS App/ContentView.swift"

# Fix the Section that has header at line 4955
sed -i '' -e '4955s/} header: {/} header: {/' "$content_file"

# Remove extraneous brace at line 5016
sed -i '' -e '5016d' "$content_file"

echo "Fixes applied to ContentView.swift"
