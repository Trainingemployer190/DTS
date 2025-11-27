#!/bin/bash

# Script to add SharedContainerHelper.swift to Xcode project
# Run this from the DTS APP directory

cd "DTS App" || exit 1

echo "🔨 Adding SharedContainerHelper.swift to Xcode project..."

# Use Ruby script to properly modify the pbxproj file
ruby << 'RUBY_SCRIPT'
require 'securerandom'

project_file = "DTS App.xcodeproj/project.pbxproj"

# Generate UUIDs (24 hex characters, Xcode style)
def generate_uuid
  SecureRandom.hex(12).upcase
end

file_ref_uuid = generate_uuid
build_file_uuid = generate_uuid

# Read project file
content = File.read(project_file)

# Find a source file to use as reference for placement
# Let's find PDFGenerator.swift and add after it
pdf_gen_match = content.match(/([A-F0-9]{24}) \/\* PDFGenerator\.swift \*\//)

if pdf_gen_match.nil?
  puts "❌ Could not find reference file. Please add manually in Xcode:"
  puts "   1. Right-click 'DTS App' group in Xcode"
  puts "   2. Choose 'Add Files to \"DTS App\"'"
  puts "   3. Select: DTS App/Utilities/SharedContainerHelper.swift"
  exit 1
end

# Add PBXBuildFile entry
build_file_section = "\t\t#{build_file_uuid} /* SharedContainerHelper.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_uuid} /* SharedContainerHelper.swift */; };\n"
content.sub!(/\/\* End PBXBuildFile section \*\//, "#{build_file_section}/* End PBXBuildFile section */")

# Add PBXFileReference entry
file_ref_section = "\t\t#{file_ref_uuid} /* SharedContainerHelper.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SharedContainerHelper.swift; sourceTree = \"<group>\"; };\n"
content.sub!(/\/\* End PBXFileReference section \*\//, "#{file_ref_section}/* End PBXFileReference section */")

# Add to sources build phase
content.sub!(/(files = \([^)]*PDFGenerator\.swift in Sources[^)]*)/m) do |match|
  match + "\n\t\t\t\t#{build_file_uuid} /* SharedContainerHelper.swift in Sources */,"
end

# Add to Utilities group (assuming it exists near PDFGenerator)
content.sub!(/(\/\* PDFGenerator\.swift \*\/,)/m) do |match|
  match + "\n\t\t\t\t#{file_ref_uuid} /* SharedContainerHelper.swift */,"
end

# Write back
File.write(project_file, content)

puts "✅ Successfully added SharedContainerHelper.swift to project"
puts "   File Reference: #{file_ref_uuid}"
puts "   Build File: #{build_file_uuid}"
puts ""
puts "Next: Open Xcode and verify the file appears in the project navigator"
RUBY_SCRIPT

echo ""
echo "✅ Done! Now:"
echo "   1. Open the project in Xcode"
echo "   2. Verify SharedContainerHelper.swift appears under Utilities"
echo "   3. Enable App Groups capability (see PHOTO_PERSISTENCE_QUICK_START.md)"
