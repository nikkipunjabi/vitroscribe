import SwiftUI

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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup initial logger, audio, etc.
        Logger.shared.log("Vitroscribe launched.")
        
        // Initialize services so listeners/timers start and notifications register
        _ = MeetingDetector.shared
        _ = GoogleCalendarService.shared
        _ = MicrosoftCalendarService.shared
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
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No update needed
    }
}
