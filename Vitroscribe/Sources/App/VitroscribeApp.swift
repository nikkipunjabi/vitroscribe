import SwiftUI
import Sparkle
import CoreGraphics
import ScreenCaptureKit

@main
struct VitroscribeApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .background(VisualEffectView().ignoresSafeArea())
                .onReceive(AudioEngineManager.shared.$isRecording) { isRecording in
                    RecordingOverlayManager.shared.updateVisibility(isRecording: isRecording)
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Vitroscribe") {
                    openWindow(id: "about")
                }
            }
        }

        Window("About Vitroscribe", id: "about") {
            AboutView()
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["autoRecordMeetings": true])
        MenuBarManager.shared.applyInitialActivationPolicy()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("Vitroscribe launched.")

        // On macOS 15, unsigned builds each carry a unique binary identity.
        // CGRequestScreenCaptureAccess / SCShareableContent both look up the
        // *current* binary in TCC, so they return false/throw even when the user
        // has a previous Vitroscribe entry toggled ON in System Settings.
        //
        // Strategy:
        //  • Call CGRequestScreenCaptureAccess() — creates a TCC entry on first
        //    run (fresh dialog) or returns the stored result silently.
        //  • Do NOT call SCShareableContent here: if the current binary has no
        //    TCC entry yet it would trigger an "Open System Settings" dialog that
        //    conflicts with the CGRequest dialog and confuses the user.
        //  • SCK is checked instead in applicationDidBecomeActive, where a TCC
        //    entry is guaranteed to exist (dialog cannot fire at that point).
        let hasPermission = CGRequestScreenCaptureAccess()
        MeetingDetector.shared.isScreenRecordingAuthorized = hasPermission

        _ = MeetingDetector.shared
        _ = GoogleCalendarService.shared
        _ = MicrosoftCalendarService.shared

        MenuBarManager.shared.setup()

        DispatchQueue.main.async {
            NSApp.windows.forEach { window in
                if !(window is NSPanel) { window.delegate = self }
            }
        }
    }

    // Re-check screen recording permission every time the app comes to the front.
    // This makes the banner disappear automatically after the user grants access
    // in System Settings without requiring an app restart.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !MeetingDetector.shared.isScreenRecordingAuthorized else { return }

        if #available(macOS 14.0, *) {
            Task.detached(priority: .background) {
                // After the user has visited System Settings, Vitroscribe is in
                // the Screen Recording list. Calling SCK here will NOT show a dialog
                // regardless of the toggle state — it simply succeeds or throws.
                let granted: Bool
                do {
                    _ = try await SCShareableContent.excludingDesktopWindows(false,
                                                                             onScreenWindowsOnly: false)
                    granted = true
                } catch {
                    granted = false
                }
                await MainActor.run {
                    MeetingDetector.shared.isScreenRecordingAuthorized = granted
                }
            }
        } else {
            MeetingDetector.shared.isScreenRecordingAuthorized = CGRequestScreenCaptureAccess()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if MenuBarManager.shared.visibilityMode == .menubarOnly {
            sender.orderOut(nil)
            return false
        }
        return true
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
