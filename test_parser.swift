import Foundation

struct CalendarJob: Identifiable {
    let id: String
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date?
}

func parseDateString(_ dateStr: String, formats: [String]) -> Date? {
    if dateStr.isEmpty {
        print("parseDateString: Empty date string")
        return nil
    }
    // Try all provided formats
    for format in formats {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: dateStr) {
            print("parseDateString: Parsed \(dateStr) with format \(format) -> \(date)")
            return date
        }
    }
    // Try ISO8601
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    if let date = isoFormatter.date(from: dateStr) {
        print("parseDateString: Parsed \(dateStr) with ISO8601 -> \(date)")
        return date
    }
    // Try date-only (yyyyMMdd)
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.dateFormat = "yyyyMMdd"
    dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
    if let date = dateOnlyFormatter.date(from: dateStr) {
        print("parseDateString: Parsed \(dateStr) with yyyyMMdd -> \(date)")
        return date
    }
    print("parseDateString: Failed to parse \(dateStr)")
    return nil
}

// Test the parsing with actual data from the calendar feed
let sampleICS = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:icalendar-ruby
CALSCALE:GREGORIAN
REFRESH-INTERVAL;VALUE=DURATION:P1H
X-PUBLISHED-TTL:P1H
BEGIN:VEVENT
DTSTAMP:20250816T082737Z
UID:4bb8d207-469a-4915-baa9-5dbe92266091
DTSTART;VALUE=DATE:20250804
DTEND;VALUE=DATE:20250809
CREATED:20250804T180505Z
DESCRIPTION:
LAST-MODIFIED:20250805T223802Z
LOCATION:105 Saint Paul Dr\\, Athens\\, GA  30606
SUMMARY:Request for Andrea Kendall
URL:https://secure.getjobber.com/to_dos/1841037912
CATEGORIES:Jobber Task
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20250816T082737Z
UID:fbbf8d07-7b2a-41da-b596-25a116b99b35
DTSTART;VALUE=DATE:20250806
DTEND;VALUE=DATE:20250807
CREATED:20250806T202019Z
DESCRIPTION:
LAST-MODIFIED:20250806T202646Z
LOCATION:123 Flowers Avenue\\, Flowery Branch\\, Georgia  30542
SUMMARY:Gutter Measuring and quote
URL:https://secure.getjobber.com/to_dos/1842830002
CATEGORIES:Jobber Task
END:VEVENT
END:VCALENDAR
"""

// Parse the sample data
var jobs: [CalendarJob] = []
let events = sampleICS.components(separatedBy: "BEGIN:VEVENT")
let dateFormats = [
    "yyyyMMdd'T'HHmmss'Z'", // UTC
    "yyyyMMdd'T'HHmmss",    // Local
    "yyyyMMdd"               // All-day
]

for event in events.dropFirst() {
    let lines = event.components(separatedBy: "\n")
    var uid = UUID().uuidString
    var title = "Job"
    var location = ""
    var startDate: Date?
    var endDate: Date?

    for line in lines {
        if line.hasPrefix("UID:") {
            uid = String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if line.hasPrefix("SUMMARY:") {
            title = String(line.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if line.hasPrefix("LOCATION:") {
            location = String(line.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if line.hasPrefix("DTSTART") {
            print("Raw DTSTART line: \(line)")
            if let colonIndex = line.firstIndex(of: ":") {
                let dateStr = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                print("Extracted DTSTART date string: '\(dateStr)'")
                startDate = parseDateString(dateStr, formats: dateFormats)
            }
        } else if line.hasPrefix("DTEND") {
            print("Raw DTEND line: \(line)")
            if let colonIndex = line.firstIndex(of: ":") {
                let dateStr = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                print("Extracted DTEND date string: '\(dateStr)'")
                endDate = parseDateString(dateStr, formats: dateFormats)
            }
        }
    }
    if let start = startDate {
        jobs.append(CalendarJob(id: uid, title: title, location: location, startDate: start, endDate: endDate))
        print("Parsed event: \(title) | \(location) | \(start)")
    } else {
        print("Skipped event (no start date): \(title)")
    }
}

print("Total parsed events: \(jobs.count)")
