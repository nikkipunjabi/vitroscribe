import Foundation
import os.log
import UserNotifications
import AppKit

struct MicrosoftEventResponse: Codable {
    let value: [MicrosoftEvent]
}

struct MicrosoftEvent: Codable {
    let id: String
    let subject: String?
    let start: MicrosoftEventTime?
    let end: MicrosoftEventTime?
    let onlineMeeting: MicrosoftOnlineMeeting?
    let location: MicrosoftLocation?
    
    struct MicrosoftEventTime: Codable {
        let dateTime: String?
        let timeZone: String?
    }
    
    struct MicrosoftOnlineMeeting: Codable {
        let joinUrl: String?
    }
    
    struct MicrosoftLocation: Codable {
        let displayName: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, subject, start, end, onlineMeeting, location, onlineMeetingUrl
    }
    
    let onlineMeetingUrl: String?
    
    func toCalendarEvent() -> CalendarEvent {
        let startDate = CalendarEvent.parseMicrosoftDate(start?.dateTime)
        let endDate = CalendarEvent.parseMicrosoftDate(end?.dateTime)
        
        return CalendarEvent(
            id: id,
            summary: subject,
            startDate: startDate,
            endDate: endDate,
            joinLink: onlineMeeting?.joinUrl ?? onlineMeetingUrl,
            source: .microsoft
        )
    }
}

extension CalendarEvent {
    static func parseMicrosoftDate(_ dateStr: String?) -> Date? {
        guard let dateStr = dateStr else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Microsoft often returns "2026-03-12T02:00:00.0000000" (no Z)
        let normalized = dateStr.contains("Z") ? dateStr : dateStr + "Z"
        return formatter.date(from: normalized) ?? ISO8601DateFormatter().date(from: normalized)
    }
}

class MicrosoftCalendarService: ObservableObject {
    static let shared = MicrosoftCalendarService()
    
    @Published var upcomingEvents: [CalendarEvent] = []
    private var syncTimer: Timer?
    private var notificationTimers: [String: Timer] = [:]
    
    private init() {
        setupSyncTimer()
    }
    
    func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }
    
    func fetchEvents() {
        guard MicrosoftAuthManager.shared.isConnected else { return }
        
        MicrosoftAuthManager.shared.getValidAccessToken { token in
            guard let token = token else { return }
            
            // Fetch events from now onwards. We use a more compatible format for the filter.
            let urlString = "https://graph.microsoft.com/v1.0/me/events?$select=id,subject,start,end,onlineMeeting,location,onlineMeetingUrl&$filter=start/dateTime ge '\(self.getCurrentISODate())'&$orderby=start/dateTime&$top=50"
            
            guard let url = URL(string: urlString) else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("outlook.timezone=\"UTC\"", forHTTPHeaderField: "Prefer")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async { 
                        MicrosoftAuthManager.shared.lastError = "Microsoft Sync Error: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(MicrosoftEventResponse.self, from: data)
                    let events = response.value.map { $0.toCalendarEvent() }
                    
                    DispatchQueue.main.async {
                        MicrosoftAuthManager.shared.lastError = ""
                        self.upcomingEvents = events
                        self.scheduleNotifications(for: events)
                        Logger.shared.log("Microsoft: Successfully synced \(events.count) events.")
                    }
                } catch {
                    Logger.shared.log("Microsoft: Decode error: \(error.localizedDescription)")
                    if let raw = String(data: data, encoding: .utf8) {
                        Logger.shared.log("Microsoft: Raw response body: \(raw)")
                        DispatchQueue.main.async {
                            MicrosoftAuthManager.shared.lastError = "Microsoft Format Error: \(error.localizedDescription)"
                        }
                    }
                }
            }.resume()
        }
    }
    
    private func getCurrentISODate() -> String {
        // Microsoft Graph filter Ge 'Date' works best with simple ISO format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date().addingTimeInterval(-3600)) // Include last hour for safety
    }
    
    private func scheduleNotifications(for events: [CalendarEvent]) {
        // Cancel old timers
        for timer in notificationTimers.values {
            timer.invalidate()
        }
        notificationTimers.removeAll()
        
        for event in events {
            guard let startDate = event.startDate else { continue }
            
            // 60 seconds before meeting
            let triggerDate = startDate.addingTimeInterval(-60)
            let timeInterval = triggerDate.timeIntervalSinceNow
            
            if timeInterval > 0 {
                let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                    self?.triggerJoinPrompt(for: event)
                }
                notificationTimers[event.id] = timer
            }
        }
    }
    
    private func triggerJoinPrompt(for event: CalendarEvent) {
        DispatchQueue.main.async {
            MeetingJoinOverlayManager.shared.show(for: event)
        }
    }
}
