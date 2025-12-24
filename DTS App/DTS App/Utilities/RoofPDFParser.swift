//
//  RoofPDFParser.swift
//  DTS App
//
//  Created by AI Assistant
//  Purpose: Parse roof measurement PDFs from various formats (iRoof, EagleView, etc.)
//

import Foundation
import PDFKit
import SwiftData

/// Result of parsing a roof measurement PDF
struct RoofParseResult {
    var measurements: RoofMeasurements
    var confidence: Double  // 0-100
    var detectedFormat: String?
    var warnings: [String]
    var rawText: String  // For debugging and format learning
    
    var isSuccessful: Bool {
        confidence > 0 && measurements.hasData
    }
}

/// Parser for roof measurement PDFs with multi-format support
class RoofPDFParser {
    
    // MARK: - Format Detection Patterns
    
    private struct FormatPattern {
        let name: String
        let identifiers: [String]  // Text patterns that identify this format
        let parser: (String) -> (RoofMeasurements, Double, [String])  // Returns (measurements, confidence, warnings)
    }
    
    private static let formats: [FormatPattern] = [
        FormatPattern(
            name: "iRoof",
            identifiers: ["iRoof", "IROOF", "iroof.com", "Roof Report"],
            parser: parseiRoofFormat
        ),
        FormatPattern(
            name: "EagleView",
            identifiers: ["EagleView", "EAGLEVIEW", "eagleview.com", "Pictometry"],
            parser: parseEagleViewFormat
        ),
        FormatPattern(
            name: "Hover",
            identifiers: ["HOVER", "hover.to", "Hover Report"],
            parser: parseHoverFormat
        ),
        FormatPattern(
            name: "RoofSnap",
            identifiers: ["RoofSnap", "ROOFSNAP"],
            parser: parseRoofSnapFormat
        ),
        FormatPattern(
            name: "Generic",
            identifiers: [],  // Fallback for unknown formats
            parser: parseGenericFormat
        )
    ]
    
    // MARK: - Public API
    
    /// Parse a PDF file from URL
    static func parse(url: URL) -> RoofParseResult {
        guard let document = PDFDocument(url: url) else {
            return RoofParseResult(
                measurements: RoofMeasurements(),
                confidence: 0,
                detectedFormat: nil,
                warnings: ["Failed to load PDF document"],
                rawText: ""
            )
        }
        
        return parse(document: document)
    }
    
    /// Parse a PDF from Data
    static func parse(data: Data) -> RoofParseResult {
        guard let document = PDFDocument(data: data) else {
            return RoofParseResult(
                measurements: RoofMeasurements(),
                confidence: 0,
                detectedFormat: nil,
                warnings: ["Failed to load PDF from data"],
                rawText: ""
            )
        }
        
        return parse(document: document)
    }
    
    /// Parse a PDFDocument
    static func parse(document: PDFDocument) -> RoofParseResult {
        // Extract all text from PDF
        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        print("📄 Extracted \(fullText.count) characters from PDF")
        
        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RoofParseResult(
                measurements: RoofMeasurements(),
                confidence: 0,
                detectedFormat: nil,
                warnings: ["PDF contains no extractable text. May be image-based."],
                rawText: fullText
            )
        }
        
        // Detect format
        var detectedFormat: FormatPattern?
        for format in formats {
            if format.identifiers.isEmpty { continue }  // Skip generic fallback
            for identifier in format.identifiers {
                if fullText.localizedCaseInsensitiveContains(identifier) {
                    detectedFormat = format
                    print("🔍 Detected format: \(format.name)")
                    break
                }
            }
            if detectedFormat != nil { break }
        }
        
        // Use generic parser if no format detected
        if detectedFormat == nil {
            detectedFormat = formats.last  // Generic fallback
            print("⚠️ No specific format detected, using generic parser")
        }
        
        // Parse using detected format
        let (measurements, confidence, warnings) = detectedFormat!.parser(fullText)
        
        return RoofParseResult(
            measurements: measurements,
            confidence: confidence,
            detectedFormat: detectedFormat?.name,
            warnings: warnings,
            rawText: fullText
        )
    }
    
    // MARK: - Format-Specific Parsers
    
    /// Parse iRoof format PDFs
    private static func parseiRoofFormat(_ text: String) -> (RoofMeasurements, Double, [String]) {
        var measurements = RoofMeasurements()
        var warnings: [String] = []
        var fieldsFound = 0
        let totalExpectedFields = 8
        
        // IMPORTANT: Parse sqft FIRST, then squares, to avoid confusion
        // Total Area in sqft - patterns like "5855.54 sqft" or "Total Area\n5855.54 sqft"
        if let sqft = extractNumber(from: text, patterns: [
            "Total\\s*Area[:\\s]*([\\d,]+\\.?\\d*)\\s*sqft",
            "([\\d,]+\\.?\\d*)\\s*sqft(?!\\s*per)",  // sqft but not "sqft per"
            "([\\d,]+\\.?\\d*)\\s*sq\\.?\\s*ft(?!\\s*per)"
        ]) {
            measurements.totalSqFt = sqft
            fieldsFound += 1
            print("✅ Found total sqft: \(sqft)")
        }
        
        // Total Squares: Look specifically for "SQ" NOT followed by "ft" or "uare"
        // Patterns like "58.56 SQ" or "Total Squares\n58.56 SQ"
        if let squares = extractNumber(from: text, patterns: [
            "Total\\s*Squares?[:\\s]*([\\d.]+)\\s*SQ(?![fF])",  // "Total Squares\n58.56 SQ" but not sqft
            "([\\d.]+)\\s*SQ(?![fFuU])",  // "58.56 SQ" but not sqft or squares
            "([\\d.]+)\\s*squares?\\s*$",
            "Total\\s*Squares?:?\\s*([\\d.]+)(?:\\s*$|\\s*\\n)"
        ]) {
            // Sanity check: squares should typically be < 200 for residential
            // If it's > 500, we probably got sqft instead
            if squares < 500 || measurements.totalSqFt == 0 {
                measurements.totalSquares = squares
                fieldsFound += 1
                print("✅ Found total squares: \(squares)")
            } else if measurements.totalSqFt == 0 {
                // This is probably sqft, not squares
                measurements.totalSqFt = squares
                measurements.totalSquares = squares / 100.0
                fieldsFound += 1
                print("⚠️ Value \(squares) looks like sqft, converting to squares: \(squares / 100.0)")
            }
        } else if measurements.totalSqFt > 0 {
            // Calculate squares from sqft if not found directly
            measurements.totalSquares = measurements.totalSqFt / 100.0
            fieldsFound += 1
            print("📊 Calculated squares from sqft: \(measurements.totalSquares)")
        } else {
            warnings.append("Could not find total squares")
        }
        
        // Ridge measurement: "Ridge\n166'10\"" or "Ridge: 166.83 ft"
        if let ridge = extractFeetInches(from: text, label: "Ridge") ??
           extractNumber(from: text, patterns: ["Ridge:?\\s*([\\d.]+)\\s*(?:ft|'|LF)"]) {
            measurements.ridgeFeet = ridge
            fieldsFound += 1
            print("✅ Found ridge: \(ridge) ft")
        } else {
            warnings.append("Could not find ridge measurement")
        }
        
        // Valley measurement
        if let valley = extractFeetInches(from: text, label: "Valley") ??
           extractNumber(from: text, patterns: ["Valley:?\\s*([\\d.]+)\\s*(?:ft|'|LF)"]) {
            measurements.valleyFeet = valley
            fieldsFound += 1
            print("✅ Found valley: \(valley) ft")
        }
        
        // Rake measurement
        if let rake = extractFeetInches(from: text, label: "Rake") ??
           extractNumber(from: text, patterns: ["Rake:?\\s*([\\d.]+)\\s*(?:ft|'|LF)"]) {
            measurements.rakeFeet = rake
            fieldsFound += 1
            print("✅ Found rake: \(rake) ft")
        } else {
            warnings.append("Could not find rake measurement")
        }
        
        // Eave measurement
        if let eave = extractFeetInches(from: text, label: "Eave") ??
           extractNumber(from: text, patterns: ["Eave:?\\s*([\\d.]+)\\s*(?:ft|'|LF)"]) {
            measurements.eaveFeet = eave
            fieldsFound += 1
            print("✅ Found eave: \(eave) ft")
        } else {
            warnings.append("Could not find eave measurement")
        }
        
        // Hip measurement
        if let hip = extractFeetInches(from: text, label: "Hip") ??
           extractNumber(from: text, patterns: ["Hip:?\\s*([\\d.]+)\\s*(?:ft|'|LF)"]) {
            measurements.hipFeet = hip
            fieldsFound += 1
            print("✅ Found hip: \(hip) ft")
        }
        
        // Step flashing
        if let stepFlashing = extractFeetInches(from: text, label: "Step Flashing") ??
           extractNumber(from: text, patterns: ["Step\\s*Flashing:?\\s*([\\d.]+)\\s*(?:ft|'|LF)"]) {
            measurements.stepFlashingFeet = stepFlashing
            fieldsFound += 1
            print("✅ Found step flashing: \(stepFlashing) ft")
        }
        
        // Pitch
        if let pitch = extractPitch(from: text) {
            measurements.pitch = pitch
            measurements.pitchMultiplier = pitchToMultiplier(pitch)
            print("✅ Found pitch: \(pitch) (multiplier: \(measurements.pitchMultiplier))")
        }
        
        // Calculate confidence based on fields found
        let confidence = Double(fieldsFound) / Double(totalExpectedFields) * 100
        
        return (measurements, min(confidence, 100), warnings)
    }
    
    /// Parse EagleView format PDFs
    private static func parseEagleViewFormat(_ text: String) -> (RoofMeasurements, Double, [String]) {
        var measurements = RoofMeasurements()
        var warnings: [String] = []
        var fieldsFound = 0
        
        // EagleView uses slightly different terminology
        // "Total Roof Area" instead of "Total Squares"
        if let area = extractNumber(from: text, patterns: [
            "Total\\s*Roof\\s*Area:?\\s*([\\d,]+\\.?\\d*)\\s*(?:sq\\.?\\s*ft|SF)",
            "Roof\\s*Area:?\\s*([\\d,]+\\.?\\d*)"
        ]) {
            measurements.totalSqFt = area
            measurements.totalSquares = area / 100.0
            fieldsFound += 2
        } else {
            warnings.append("Could not find roof area")
        }
        
        // EagleView labels
        if let ridge = extractNumber(from: text, patterns: ["Ridge(?:/Hip)?:?\\s*([\\d.]+)\\s*(?:ft|LF)"]) {
            measurements.ridgeFeet = ridge
            fieldsFound += 1
        }
        
        if let valley = extractNumber(from: text, patterns: ["Valley:?\\s*([\\d.]+)\\s*(?:ft|LF)"]) {
            measurements.valleyFeet = valley
            fieldsFound += 1
        }
        
        if let rake = extractNumber(from: text, patterns: ["Rake:?\\s*([\\d.]+)\\s*(?:ft|LF)"]) {
            measurements.rakeFeet = rake
            fieldsFound += 1
        }
        
        if let eave = extractNumber(from: text, patterns: ["Eave(?:s)?:?\\s*([\\d.]+)\\s*(?:ft|LF)"]) {
            measurements.eaveFeet = eave
            fieldsFound += 1
        }
        
        if let pitch = extractPitch(from: text) {
            measurements.pitch = pitch
            measurements.pitchMultiplier = pitchToMultiplier(pitch)
        }
        
        let confidence = Double(fieldsFound) / 6.0 * 100
        return (measurements, min(confidence, 100), warnings)
    }
    
    /// Parse Hover format PDFs
    private static func parseHoverFormat(_ text: String) -> (RoofMeasurements, Double, [String]) {
        // Hover uses similar format to EagleView
        return parseEagleViewFormat(text)
    }
    
    /// Parse RoofSnap format PDFs
    private static func parseRoofSnapFormat(_ text: String) -> (RoofMeasurements, Double, [String]) {
        // RoofSnap parsing - similar to iRoof
        return parseiRoofFormat(text)
    }
    
    /// Generic parser for unknown formats
    private static func parseGenericFormat(_ text: String) -> (RoofMeasurements, Double, [String]) {
        var measurements = RoofMeasurements()
        var warnings: [String] = ["Using generic parser - results may be less accurate"]
        var fieldsFound = 0
        
        // IMPORTANT: Parse sqft FIRST to avoid confusion with SQ (squares)
        // Look for patterns like "5855.54 sqft" or "Total Area\n5855.54 sqft"
        if let sqft = extractNumber(from: text, patterns: [
            "Total\\s*Area[:\\s\\n]*([\\d,]+\\.?\\d*)\\s*sqft",
            "([\\d,]+\\.?\\d*)\\s*sqft(?!\\s*per)",
            "([\\d,]+\\.?\\d*)\\s*sq\\.?\\s*ft(?!\\s*per)"
        ]) {
            measurements.totalSqFt = sqft
            fieldsFound += 1
            print("✅ Generic: Found sqft: \(sqft)")
        }
        
        // Now look for squares - "58.56 SQ" but NOT "sqft"
        // Pattern should match "SQ" at word boundary, not followed by "ft"
        if let squares = extractNumber(from: text, patterns: [
            "Total\\s*Squares?[:\\s\\n]*([\\d.]+)\\s*SQ(?![fFuU])",
            "([\\d.]+)\\s+SQ(?![fFuU])",  // Space before SQ, not followed by ft
            "([\\d.]+)\\s*squares?(?:\\s|\\n|$)"
        ]) {
            // Sanity check: squares for residential are typically 10-200
            if squares < 500 {
                measurements.totalSquares = squares
                fieldsFound += 1
                print("✅ Generic: Found squares: \(squares)")
            } else {
                // This is probably sqft misread as squares
                if measurements.totalSqFt == 0 {
                    measurements.totalSqFt = squares
                    measurements.totalSquares = squares / 100.0
                    print("⚠️ Generic: \(squares) looks like sqft, converting to \(squares/100) squares")
                }
                fieldsFound += 1
            }
        } else if measurements.totalSqFt > 0 {
            // Calculate squares from sqft
            measurements.totalSquares = measurements.totalSqFt / 100.0
            fieldsFound += 1
            print("📊 Generic: Calculated squares: \(measurements.totalSquares)")
        }
        
        // Try generic linear foot patterns with feet/inches format like "133' 10\""
        // IMPORTANT: Parse eave BEFORE drip edge to avoid overwriting
        let lfPatterns: [(String, WritableKeyPath<RoofMeasurements, Double>)] = [
            ("ridge", \.ridgeFeet),
            ("valley", \.valleyFeet),
            ("rake", \.rakeFeet),
            ("eave", \.eaveFeet),
            ("hip", \.hipFeet),
            ("step\\s*flashing", \.stepFlashingFeet)
            // NOTE: Drip edge is NOT parsed separately - it's calculated from eave + rake in the calculator
        ]
        
        for (label, keyPath) in lfPatterns {
            // Skip if already has a value (don't overwrite)
            if measurements[keyPath: keyPath] > 0 {
                continue
            }
            
            // Try feet'inches" format first (e.g., "133' 10\"")
            if let value = extractFeetInchesGeneric(from: text, label: label) {
                measurements[keyPath: keyPath] = value
                fieldsFound += 1
                print("✅ Generic: Found \(label): \(value) ft")
            } else if let value = extractNumber(from: text, patterns: [
                "\(label)[\\s\\n:]+([\\d.]+)\\s*(?:ft|'|LF|linear)?",
                "\(label)[\\s\\n:]+([\\d]+)'\\s*([\\d]+)?\""
            ]) {
                measurements[keyPath: keyPath] = value
                fieldsFound += 1
                print("✅ Generic: Found \(label): \(value) ft")
            }
        }
        
        if let pitch = extractPitch(from: text) {
            measurements.pitch = pitch
            measurements.pitchMultiplier = pitchToMultiplier(pitch)
            print("✅ Generic: Found pitch: \(pitch)")
        }
        
        // Extract low-pitch areas (under 4/12) for ice & water requirements
        extractLowPitchAreas(from: text, into: &measurements)
        
        // Lower confidence for generic parser
        let confidence = Double(fieldsFound) / 8.0 * 100 * 0.8  // 20% penalty for generic
        
        if fieldsFound == 0 {
            warnings.append("No measurements could be extracted. Please enter manually.")
        }
        
        return (measurements, min(confidence, 100), warnings)
    }
    
    /// Extract low-pitch areas from PDF text
    /// Looks for patterns like "Area 1 Pitch 4/12: 1804.63 sqft" or "4/12\n1804 sqft"
    /// Also detects transitions between different pitches
    private static func extractLowPitchAreas(from text: String, into measurements: inout RoofMeasurements, threshold: Int = 4) {
        // Pattern: "Area X Pitch N/12: XXXX sqft" or "Pitch N/12: XXXX"
        let patterns = [
            "Area\\s*(\\d+)\\s*(?:Pitch)?\\s*(\\d+)/12[:\\s]*([\\d,]+\\.?\\d*)\\s*sqft",
            "(\\d+)/12[:\\s]*([\\d,]+\\.?\\d*)\\s*sqft",
            "Pitch\\s*(\\d+)/12[:\\s]*([\\d,]+\\.?\\d*)\\s*(?:sqft|sq\\s*ft)"
        ]
        
        var lowPitchTotal: Double = 0
        var lowPitchDescriptions: [String] = []
        var allPitches: [Int] = []  // Track all pitches found to detect transitions
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                var pitchValue: Int = 0
                var sqft: Double = 0
                var areaName = ""
                
                if match.numberOfRanges >= 4 {
                    // Pattern with Area number: "Area 1 Pitch 4/12: 1804 sqft"
                    if let areaRange = Range(match.range(at: 1), in: text) {
                        areaName = "Area \(text[areaRange])"
                    }
                    if let pitchRange = Range(match.range(at: 2), in: text) {
                        pitchValue = Int(text[pitchRange]) ?? 0
                    }
                    if let sqftRange = Range(match.range(at: 3), in: text) {
                        let sqftStr = String(text[sqftRange]).replacingOccurrences(of: ",", with: "")
                        sqft = Double(sqftStr) ?? 0
                    }
                } else if match.numberOfRanges >= 3 {
                    // Pattern without Area: "4/12: 1804 sqft"
                    if let pitchRange = Range(match.range(at: 1), in: text) {
                        pitchValue = Int(text[pitchRange]) ?? 0
                    }
                    if let sqftRange = Range(match.range(at: 2), in: text) {
                        let sqftStr = String(text[sqftRange]).replacingOccurrences(of: ",", with: "")
                        sqft = Double(sqftStr) ?? 0
                    }
                }
                
                // Track all pitches for transition detection
                if pitchValue > 0 && !allPitches.contains(pitchValue) {
                    allPitches.append(pitchValue)
                }
                
                // Check if this is a low-pitch area (UNDER threshold, e.g., 3/12 and below, NOT 4/12)
                if pitchValue > 0 && pitchValue < threshold && sqft > 0 {
                    lowPitchTotal += sqft
                    let description = areaName.isEmpty ? "\(pitchValue)/12: \(String(format: "%.0f", sqft)) sqft" : "\(areaName) \(pitchValue)/12: \(String(format: "%.0f", sqft)) sqft"
                    lowPitchDescriptions.append(description)
                    print("⚠️ Found low-pitch area (under \(threshold)/12): \(description)")
                }
            }
        }
        
        measurements.lowPitchSqFt = lowPitchTotal
        measurements.lowPitchAreas = lowPitchDescriptions
        
        // Detect transitions - if multiple different pitches exist, there are transitions
        // Look for "Transition" in the text to get actual LF
        if let transitionLF = extractFeetInchesGeneric(from: text, label: "transition") {
            measurements.transitionFeet = transitionLF
            print("✅ Found transition: \(transitionLF) LF")
        } else if allPitches.count > 1 {
            // Multiple pitches found - there must be transitions between them
            // The PDF shows "Transition 113' 11"" for your example
            allPitches.sort()
            var transitionDescs: [String] = []
            for i in 0..<(allPitches.count - 1) {
                transitionDescs.append("\(allPitches[i])/12 to \(allPitches[i+1])/12")
            }
            measurements.transitionDescriptions = transitionDescs
            print("📊 Detected pitch transitions: \(transitionDescs.joined(separator: ", "))")
            // Note: Transition LF should be parsed from "Transition\n113' 11\"" if present
        }
        
        if lowPitchTotal > 0 {
            print("📊 Total low-pitch area requiring ice & water: \(lowPitchTotal) sqft")
        }
    }
    
    /// Extract feet and inches in format "133' 10\"" or "133'10\""
    private static func extractFeetInchesGeneric(from text: String, label: String) -> Double? {
        let pattern = "\(label)[\\s\\n:]*([\\d]+)'\\s*([\\d]+)?(?:\"|''|in)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range),
           let feetRange = Range(match.range(at: 1), in: text) {
            let feet = Double(text[feetRange]) ?? 0
            var inches: Double = 0
            if match.numberOfRanges > 2,
               let inchRange = Range(match.range(at: 2), in: text) {
                inches = Double(text[inchRange]) ?? 0
            }
            return feet + (inches / 12.0)
        }
        return nil
    }
    
    // MARK: - Helper Functions
    
    /// Extract a number using multiple regex patterns
    private static func extractNumber(from text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let valueRange = Range(match.range(at: 1), in: text) {
                var valueString = String(text[valueRange])
                valueString = valueString.replacingOccurrences(of: ",", with: "")
                if let value = Double(valueString) {
                    return value
                }
            }
        }
        return nil
    }
    
    /// Extract feet and inches measurement like "166'10\""
    private static func extractFeetInches(from text: String, label: String) -> Double? {
        // Pattern: "Label\n166'10\"" or "Label: 166'10\""
        let patterns = [
            "\(label)\\s*[:\\n]\\s*(\\d+)'(\\d+)\"",
            "\(label)\\s*[:\\n]\\s*(\\d+)\\s*ft\\s*(\\d+)\\s*in"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               match.numberOfRanges >= 3,
               let feetRange = Range(match.range(at: 1), in: text),
               let inchesRange = Range(match.range(at: 2), in: text) {
                let feet = Double(String(text[feetRange])) ?? 0
                let inches = Double(String(text[inchesRange])) ?? 0
                return feet + (inches / 12.0)
            }
        }
        
        return nil
    }
    
    /// Extract roof pitch like "6/12" or "6:12"
    private static func extractPitch(from text: String) -> String? {
        let patterns = [
            "(\\d+)\\s*/\\s*12",  // 6/12
            "(\\d+)\\s*:\\s*12",  // 6:12
            "(\\d+)/12\\s*pitch",
            "pitch[:\\s]+(\\d+)/12"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let riseRange = Range(match.range(at: 1), in: text) {
                let rise = String(text[riseRange])
                return "\(rise)/12"
            }
        }
        
        return nil
    }
    
    /// Convert pitch string to area multiplier
    private static func pitchToMultiplier(_ pitch: String) -> Double {
        // Extract rise from "X/12"
        let components = pitch.components(separatedBy: "/")
        guard components.count == 2,
              let rise = Double(components[0]) else {
            return 1.0
        }
        
        // Calculate: sqrt(rise^2 + 12^2) / 12
        let multiplier = sqrt(pow(rise, 2) + 144) / 12.0
        return multiplier
    }
    
    // MARK: - Manual Entry Support
    
    /// Create a RoofMeasurements from manual entry (when parsing fails)
    static func createManualMeasurements(
        totalSquares: Double? = nil,
        totalSqFt: Double? = nil,
        ridgeFeet: Double = 0,
        valleyFeet: Double = 0,
        rakeFeet: Double = 0,
        eaveFeet: Double = 0,
        hipFeet: Double = 0,
        stepFlashingFeet: Double = 0,
        pitch: String? = nil
    ) -> RoofMeasurements {
        var m = RoofMeasurements()
        
        if let squares = totalSquares {
            m.totalSquares = squares
            m.totalSqFt = squares * 100
        } else if let sqft = totalSqFt {
            m.totalSqFt = sqft
            m.totalSquares = sqft / 100.0
        }
        
        m.ridgeFeet = ridgeFeet
        m.valleyFeet = valleyFeet
        m.rakeFeet = rakeFeet
        m.eaveFeet = eaveFeet
        m.hipFeet = hipFeet
        m.stepFlashingFeet = stepFlashingFeet
        
        if let pitch = pitch {
            m.pitch = pitch
            m.pitchMultiplier = pitchToMultiplier(pitch)
        }
        
        return m
    }
}
