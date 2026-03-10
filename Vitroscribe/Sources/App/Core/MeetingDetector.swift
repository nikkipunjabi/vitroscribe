import Foundation
import AppKit
import os.log
import UserNotifications

class MeetingDetector: ObservableObject {
    static let shared = MeetingDetector()
    
    @Published var isMeetingActive: Bool = false
    @Published var isScreenRecordingAuthorized: Bool = true
    private var checkTimer: Timer?
    
    // Grace Period Logic (v12.2)
    private var consecutiveHits: Int = 0
    private var consecutiveMisses: Int = 0
    private let hitsRequiredToStart = 2   // 10 seconds of "Found" to start
    private let missesRequiredToStop = 3   // 15 seconds of "Not Found" to stop
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Poll every 5 seconds
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForActiveMeetings()
        }
        
        Logger.shared.log("Meeting detector started monitoring with 20s grace period.")
    }
    
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
        Logger.shared.log("Meeting detector stopped monitoring.")
    }
    
    private func checkForActiveMeetings() {
        // 0. Update permission status (v12.6 Fix)
        // We check if we can see titles of ANY window that isn't ours
        let preFlightOptions = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
        if let windowList = CGWindowListCopyWindowInfo(preFlightOptions, kCGNullWindowID) as? [[String: Any]] {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let hasExternalTitles = windowList.contains { window in
                let windowPID = window[kCGWindowOwnerPID as String] as? Int32 ?? 0
                let windowName = window[kCGWindowName as String] as? String
                return windowPID != ownPID && windowName != nil && !windowName!.isEmpty
            }
            DispatchQueue.main.async {
                self.isScreenRecordingAuthorized = hasExternalTitles
            }
        }

        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        var meetingFound = false
        var exactMeetingMatch = false
        var diagnosticLog = "--- Window Scan ---\n"
        var isBrowserOpen = false
        
        // Ensure browser open is registered even if window scan misses it due to permissions
        let runningApps = NSWorkspace.shared.runningApplications
        let browsers = ["Google Chrome", "Arc", "Safari", "Microsoft Edge"]
        for app in runningApps {
            if let name = app.localizedName, browsers.contains(name) {
                isBrowserOpen = true
                break
            }
        }
        
        for window in windowList {
            let windowName = window[kCGWindowName as String] as? String ?? "EMPTY_TITLE"
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "UNKNOWN_OWNER"
            
            diagnosticLog += "[\(ownerName)] \(windowName)\n"
            
            let lowerWindow = windowName.lowercased()
            let lowerOwner = ownerName.lowercased()
            
            // 1. Strict Exact Matches (definitively a meeting going on based on the title)
            let isZoomStrict = lowerOwner.contains("zoom") && lowerWindow.contains("meeting")
            let isTeamsStrict = lowerOwner.contains("teams") && (lowerWindow.contains("meeting ") || lowerWindow.contains(" meeting") || lowerWindow.hasPrefix("call with"))
            let isWebexStrict = (lowerOwner.contains("webex") || lowerOwner.contains("cisco")) && lowerWindow.contains("meeting")
            let isSlackStrict = lowerOwner.contains("slack") && (lowerWindow.contains("huddle ") || lowerWindow.contains(" huddle") || lowerWindow.hasPrefix("meet ") || lowerWindow.contains(" meet"))
            
            // 2. Browser-based Meeting Heuristics (Google Meet, etc.) (These are always exact matches)
            let isBrowserMatch = ["google chrome", "safari", "firefox", "microsoft edge", "arc"].contains(lowerOwner)
            if isBrowserMatch { isBrowserOpen = true }
            
            let isMeet = isBrowserMatch && lowerWindow.contains("meet -")
            // Teams in browser changes title to "Meeting | Microsoft Teams" or "Call | ". No longer match plain "teams.microsoft.com".
            let isBrowserTeams = isBrowserMatch && lowerWindow.contains("teams") && (lowerWindow.hasPrefix("meeting |") || lowerWindow.hasPrefix("call |"))
            
            if isZoomStrict || isTeamsStrict || isWebexStrict || isSlackStrict || isMeet || isBrowserTeams {
                meetingFound = true
                exactMeetingMatch = true
                break
            }
            
            // 3. Broad Matches (App is simply open, e.g. floating window or main UI)
            let isZoomBroad = lowerOwner.contains("zoom") && (lowerWindow.contains("zoom") || windowName.isEmpty || windowName == "EMPTY_TITLE")
            let isTeamsBroad = lowerOwner.contains("teams") && (lowerWindow.contains("microsoft teams") || windowName.isEmpty || windowName == "EMPTY_TITLE")
            let isWebexBroad = (lowerOwner.contains("webex") || lowerOwner.contains("cisco")) && (lowerWindow.contains("webex") || windowName.isEmpty || windowName == "EMPTY_TITLE")
            let isSlackBroad = lowerOwner.contains("slack") && (lowerWindow == "slack" || windowName.isEmpty || windowName == "EMPTY_TITLE")
            
            if isZoomBroad || isTeamsBroad || isWebexBroad || isSlackBroad {
                meetingFound = true
                // Note: We DO NOT break here, so if there is an exact match hiding further down the window list, we can still catch it!
            }
        }
        
        // 2.5 Alternative Detection: AppleScript URL Check (v12.6)
        if !exactMeetingMatch && isBrowserOpen {
            let browsers = ["Google Chrome", "Arc", "Safari", "Microsoft Edge"]
            for browser in browsers {
                if let urls = getActiveTabURLs(for: browser) {
                    for url in urls {
                        if isRealMeetingURL(url) {
                            Logger.shared.log("URL Detection: Found meeting link in \(browser): \(url)")
                            meetingFound = true
                            exactMeetingMatch = true
                            break
                        }
                    }
                    if exactMeetingMatch { break }
                }
            }
        }
        
        // 3. SPECIAL FALLBACK: Calendar-based auto-detect (v12.4)
        // If titles are hidden (permission issue) but a meeting is scheduled RIGHT NOW and browser is open
        if !exactMeetingMatch && !isScreenRecordingAuthorized && isBrowserOpen {
            let now = Date()
            let scheduledMeetings = GoogleCalendarService.shared.upcomingEvents.filter { event in
                guard let start = event.startDate, let end = event.endDate else { return false }
                // Give a 5-minute buffer before/after
                return now >= start.addingTimeInterval(-300) && now <= end.addingTimeInterval(300)
            }
            
            if !scheduledMeetings.isEmpty {
                Logger.shared.log("Calendar Fallback: No window titled 'Meet' found (hidden), but a meeting is scheduled now and Chrome is open. Triggering auto-start.")
                meetingFound = true
                exactMeetingMatch = true
            }
        }
        
        // If no meeting found, log the top 5 windows to see why
        if !meetingFound && consecutiveHits == 0 {
            if diagnosticLog.contains("Chrome") && !isScreenRecordingAuthorized {
                Logger.shared.log("WARNING: Chrome detected but window titles are hidden. Screen Recording permission required for title-based detection. Using Calendar Fallback.")
            }
        }
        
        DispatchQueue.main.async {
            let audioManager = AudioEngineManager.shared
            let audioStreamMonitor = AudioStreamMonitor.shared
            
            // Confidence Logic (v13.0): Meeting found ONLY IF audio is flowing AND (URL/App match OR Calendar match)
            let highConfidenceMeetingFound = meetingFound && audioStreamMonitor.isAudioFlowing
            
            if highConfidenceMeetingFound {
                self.consecutiveMisses = 0
                self.consecutiveHits += 1
                
                if self.consecutiveHits >= self.hitsRequiredToStart && !self.isMeetingActive {
                    self.isMeetingActive = true
                    Logger.shared.log("High Confidence Trigger: Audio + URL/App matched. Prompting user to start recording.")
                    self.sendRecordingPromptNotification()
                }
            } else {
                self.consecutiveHits = 0
                // Auto-Stop: Triggered only when the meeting URL/Process is closed (not based on silence)
                if self.isMeetingActive || (audioManager.isRecording && !audioManager.isManualRecording) {
                    self.consecutiveMisses += 1
                    
                    // We stop if we completely lost the app entirely OR if we only have a broad match but the hardware audio stopped flowing.
                    let shouldStop = !meetingFound || (!exactMeetingMatch && !audioStreamMonitor.isAudioFlowing)
                    
                    if self.consecutiveMisses >= self.missesRequiredToStop || shouldStop {
                        // Check if we lost the URL/App match entirely or audio stopped on a broad match
                        if shouldStop {
                            if self.isMeetingActive {
                                Logger.shared.log("Meeting context/audio lost. Auto-stopping.")
                            } else {
                                Logger.shared.log("Recording active without meeting context. Cleaning up.")
                            }
                            self.isMeetingActive = false
                            self.consecutiveMisses = 0
                            audioManager.stopRecording()
                        } else {
                            // Meeting match still exists, but audio might be quiet. 
                            // User asked NOT to stop on silence, so we stay active.
                            self.consecutiveMisses = 0 
                        }
                    }
                } else {
                    self.consecutiveMisses = 0
                }
            }
        }
    }
    
    private func getActiveTabURLs(for appName: String) -> [String]? {
        var scriptSource = ""
        if appName == "Google Chrome" || appName == "Arc" || appName == "Microsoft Edge" {
            scriptSource = """
            tell application "\(appName)"
                set urlList to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        set end of urlList to URL of t
                    end repeat
                end repeat
                return urlList
            end tell
            """
        } else if appName == "Safari" {
            scriptSource = """
            tell application "Safari"
                set urlList to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        set end of urlList to URL of t
                    end repeat
                end repeat
                return urlList
            end tell
            """
        }
        
        guard !scriptSource.isEmpty else { return nil }
        
        let script = NSAppleScript(source: scriptSource)
        var error: NSDictionary?
        if let output = script?.executeAndReturnError(&error) {
            // AppleScript lists are represented recursively or comma-separated depending on the descriptor
            // The safest extraction is using stringValue assuming comma space separated, but coercing list elements is better.
            var urls: [String] = []
            let count = output.numberOfItems
            if count > 0 {
                for i in 1...count {
                    if let itemStr = output.atIndex(i)?.stringValue {
                        urls.append(itemStr)
                    }
                }
            }
            // Fallback to string split if it didn't iterate
            if urls.isEmpty, let singleStr = output.stringValue {
                urls = singleStr.components(separatedBy: ", ")
            }
            return urls
        } else if let error = error {
            Logger.shared.log("AppleScript error for \(appName): \(error)")
        }
        return nil
    }
    
    private func sendRecordingPromptNotification() {
        // Since standard notifications fail without entitlements, use our custom SwiftUI floating toast prompt overlay
        PromptOverlayManager.shared.show()
    }
    
    private func isRealMeetingURL(_ urlString: String) -> Bool {
        let lowerURL = urlString.lowercased()
        
        // Google Meet: Must not be landing, home, or empty path
        if lowerURL.contains("meet.google.com") {
            // Must have meet.google.com/ and then a 10-12 character code or similar
            guard let range = lowerURL.range(of: "meet.google.com/") else { return false }
            let afterDomain = lowerURL[range.upperBound...]
            
            // Remove query parameters and fragments
            let pathOnly = afterDomain.components(separatedBy: "?")[0]
                                    .components(separatedBy: "#")[0]
                                    .trimmingCharacters(in: .init(charactersIn: "/"))
            
            // Explicitly exclude non-meeting paths
            let excluded = ["", "landing", "new", "check", "h", "home", "lookup"]
            if excluded.contains(pathOnly) { return false }
            
            // Meeting codes are usually like abc-defg-hij (12 chars total)
            // or alias names. Landing pages like 'landing' or 'check' are excluded above.
            // If it's just 'meet.google.com/' or redirect, it's not a meeting.
            return pathOnly.count >= 4
        }
        
        // Zoom, Teams, Webex
        if lowerURL.contains("zoom.us/j/") || 
           lowerURL.contains("teams.microsoft.com/l/meetup-join") ||
           lowerURL.contains("webex.com/meet") {
            return true
        }
        
        return false
    }
}
