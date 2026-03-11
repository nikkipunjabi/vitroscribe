import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let summary: String?
    let startDate: Date?
    let endDate: Date?
    let joinLink: String?
    let source: EventSource
    
    enum EventSource: String, Codable {
        case google
        case microsoft
    }
}

struct MeetingLinkExtractor {
    static func extract(from texts: [String?]) -> String? {
        // Regex for Google Meet, Zoom, and Teams
        let patterns = [
            "https://meet.google.com/[a-z0-9-]+",
            "https://[a-z0-0.]*zoom.us/j/[0-9?%a-zA-Z=-]+",
            "https://teams.microsoft.com/l/meetup-join/[a-zA-Z0-9%._/-?=&+]+"
        ]
        
        for text in texts {
            guard let text = text else { continue }
            for pattern in patterns {
                if let range = text.range(of: pattern, options: .regularExpression) {
                    return String(text[range])
                }
            }
        }
        return nil
    }
}
