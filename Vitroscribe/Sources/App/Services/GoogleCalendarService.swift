import Foundation
import os.log
import UserNotifications
import AppKit

struct GoogleEventResponse: Codable {
    let items: [GoogleEvent]?
}

struct GoogleEvent: Identifiable, Codable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: EventTime?
    let end: EventTime?
    let hangoutLink: String?
    
    struct EventTime: Codable {
        let dateTime: String?
        let timeZone: String?
    }
    
    func toCalendarEvent() -> CalendarEvent {
        let formatter = ISO8601DateFormatter()
        let startDate = start?.dateTime != nil ? formatter.date(from: start!.dateTime!) : nil
        let endDate = end?.dateTime != nil ? formatter.date(from: end!.dateTime!) : nil
        
        let joinLink = hangoutLink ?? MeetingLinkExtractor.extract(from: [location, description])
        
        return CalendarEvent(
            id: id,
            summary: summary,
            startDate: startDate,
            endDate: endDate,
            joinLink: joinLink,
            source: .google
        )
    }
}

class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()
    
    @Published var upcomingEvents: [CalendarEvent] = []
    private var syncTimer: Timer?
    private var notificationTimers: [String: Timer] = [:]
    
    private init() {
        requestNotificationPermission()
        setupSyncTimer()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                Logger.shared.log("Notification permission granted.")
            } else if let error = error {
                Logger.shared.log("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func setupSyncTimer() {
        // Sync immediately and then every hour (3600 seconds)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }
    
    func fetchEvents() {
        guard GoogleAuthManager.shared.isConnected else { return }
        
        GoogleAuthManager.shared.getValidAccessToken { token in
            guard let token = token else { return }
            
            let dateFormatter = ISO8601DateFormatter()
            let timeMin = dateFormatter.string(from: Date())
            
            // Get upcoming 50 events with specific fields for discovery
            let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&maxResults=50&orderBy=startTime&singleEvents=true&fields=items(id,summary,description,location,start,end,hangoutLink)"
            
            guard let url = URL(string: urlString) else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                guard let data = data, error == nil else { return }
                do {
                    let response = try JSONDecoder().decode(GoogleEventResponse.self, from: data)
                    let items = response.items ?? []
                    let events = items.map { $0.toCalendarEvent() }
                    
                    DispatchQueue.main.async {
                        self.upcomingEvents = events
                        self.scheduleNotifications(for: events)
                        Logger.shared.log("Google: Fetched \(events.count) upcoming events.")
                    }
                } catch {
                    Logger.shared.log("Google: Error parsing events: \(error.localizedDescription)")
                }
            }.resume()
        }
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
        
        // Optional: Keep system notification as a backup
        self.sendNotification(for: event)
    }
    
    private func sendNotification(for event: CalendarEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting starting in 1 minute"
        content.body = event.summary ?? "Upcoming Meeting"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
