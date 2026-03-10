import Foundation
import os.log
import UserNotifications
import AppKit

struct GoogleEvent: Identifiable, Codable {
    let id: String
    let summary: String?
    let start: EventTime?
    let end: EventTime?
    let hangoutLink: String?
    
    struct EventTime: Codable {
        let dateTime: String?
        let timeZone: String?
    }
    
    var startDate: Date? {
        guard let dtString = start?.dateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dtString)
    }
    
    var endDate: Date? {
        guard let dtString = end?.dateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dtString)
    }
}

class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()
    
    @Published var upcomingEvents: [GoogleEvent] = []
    private var syncTimer: Timer?
    private var notificationTimers: [String: Timer] = [:]
    
    private init() {
        requestNotificationPermission()
        setupSyncTimer()
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
            
            // Get upcoming 10 events
            let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&maxResults=20&orderBy=startTime&singleEvents=true"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                guard let data = data, error == nil else {
                    Logger.shared.log("Failed to fetch events: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let items = json["items"] as? [[String: Any]] {
                        
                        let data = try JSONSerialization.data(withJSONObject: items)
                        let events = try JSONDecoder().decode([GoogleEvent].self, from: data)
                        
                        DispatchQueue.main.async {
                            // Only keep future events, sort and limit to 10 as requested (we fetch 20 to have buffer, UI can paginate)
                            let futureEvents = events.filter { $0.startDate != nil && $0.startDate! > Date() }.sorted(by: { $0.startDate! < $1.startDate! })
                            self.upcomingEvents = Array(futureEvents.prefix(20))
                            self.scheduleNotifications(for: self.upcomingEvents)
                            Logger.shared.log("Successfully fetched \(self.upcomingEvents.count) upcoming events.")
                        }
                    }
                } catch {
                    Logger.shared.log("Error decoding events: \(error.localizedDescription)")
                }
            }.resume()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                Logger.shared.log("Notification permission granted.")
                
                // Set up actionable notifications
                let startAction = UNNotificationAction(identifier: "START_RECORDING", title: "Yes, Start Recording", options: .foreground)
                let dismissAction = UNNotificationAction(identifier: "DISMISS_RECORDING", title: "No, thanks", options: .destructive)
                let category = UNNotificationCategory(identifier: "RECORDING_PROMPT", actions: [startAction, dismissAction], intentIdentifiers: [], options: [])
                UNUserNotificationCenter.current().setNotificationCategories([category])
                
            } else {
                Logger.shared.log("Notification permission denied.")
            }
        }
        
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    private func scheduleNotifications(for events: [GoogleEvent]) {
        // Clear old timers
        for timer in notificationTimers.values {
            timer.invalidate()
        }
        notificationTimers.removeAll()
        
        for event in events {
            guard let startDate = event.startDate else { continue }
            
            // 30 seconds before meeting
            let triggerDate = startDate.addingTimeInterval(-30)
            let timeInterval = triggerDate.timeIntervalSinceNow
            
            if timeInterval > 0 {
                let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                    self?.sendNotification(for: event)
                }
                notificationTimers[event.id] = timer
            }
        }
    }
    
    private func sendNotification(for event: GoogleEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting starting in 30 seconds"
        content.body = event.summary ?? "Upcoming Meeting"
        content.sound = UNNotificationSound.default
        
        if let link = event.hangoutLink {
            content.userInfo = ["url": link]
        }
        
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil) // Deliver immediately
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.log("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                Logger.shared.log("Delivered notification for \(event.summary ?? "Meeting").")
            }
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "START_RECORDING" {
            DispatchQueue.main.async {
                AudioEngineManager.shared.startRecording(manual: false)
                Logger.shared.log("User accepted to start recording via notification.")
            }
        } else if response.actionIdentifier == "DISMISS_RECORDING" {
            DispatchQueue.main.async {
                Logger.shared.log("User declined to start recording.")
                // Notice we keep MeetingDetector.shared.isMeetingActive as true so we don't spam prompt
            }
        } else {
            // Default action
            let userInfo = response.notification.request.content.userInfo
            if let urlString = userInfo["url"] as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
