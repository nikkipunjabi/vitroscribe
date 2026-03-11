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
