import Foundation

struct CalendarJob: Identifiable {
    let id: String
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date?
}

class ICalendarManager {
    private let calendarURL: URL
    
    init(calendarURL: URL) {
        self.calendarURL = calendarURL
    }
    
    func fetchJobs(completion: @escaping ([CalendarJob]) -> Void) {
        let task = URLSession.shared.dataTask(with: calendarURL) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            let jobs = self.parseICS(data: data)
            completion(jobs)
        }
        task.resume()
    }
    
    private func parseICS(data: Data) -> [CalendarJob] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        var jobs: [CalendarJob] = []
        let events = content.components(separatedBy: "BEGIN:VEVENT")
        for event in events.dropFirst() {
            let lines = event.components(separatedBy: "\n")
            var uid = UUID().uuidString
            var title = "Job"
            var location = ""
            var startDate: Date?
            var endDate: Date?
            // Try multiple date formats
            let dateFormats = [
                "yyyyMMdd'T'HHmmss'Z'", // UTC
                "yyyyMMdd'T'HHmmss",    // Local
                "yyyyMMdd"               // All-day
            ]
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
        return jobs
    }

    private func parseDateString(_ dateStr: String, formats: [String]) -> Date? {
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
        // Try UTC date-time (e.g., 20250816T210000Z)
        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = utcFormatter.date(from: dateStr) {
            print("parseDateString: Parsed \(dateStr) with yyyyMMdd'T'HHmmss'Z' -> \(date)")
            return date
        }
        // Try UTC date-time without Z (e.g., 20250816T210000)
        let utcNoZFormatter = DateFormatter()
        utcNoZFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        utcNoZFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcNoZFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = utcNoZFormatter.date(from: dateStr) {
            print("parseDateString: Parsed \(dateStr) with yyyyMMdd'T'HHmmss (no Z) -> \(date)")
            return date
        }
        // Try local date-time (fallback to current timezone)
        let tzFormatter = DateFormatter()
        tzFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        tzFormatter.timeZone = TimeZone.current
        tzFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = tzFormatter.date(from: dateStr) {
            print("parseDateString: Parsed \(dateStr) with yyyyMMdd'T'HHmmss (local tz) -> \(date)")
            return date
        }
        print("parseDateString: Failed to parse \(dateStr)")
        return nil
    }
}
