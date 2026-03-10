import Foundation
import ServiceManagement
import os.log

class StartupManager {
    static let shared = StartupManager()
    
    private init() {}
    
    func isLaunchAtStartupEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false // Fallback
        }
    }
    
    func setLaunchAtStartup(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        Logger.shared.log("Launch at startup enabled.")
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        Logger.shared.log("Launch at startup disabled.")
                    }
                }
            } catch {
                Logger.shared.log("Failed to set launch at startup: \(error.localizedDescription)")
            }
        }
    }
}
