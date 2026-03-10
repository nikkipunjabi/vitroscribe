import SwiftUI

@main
struct VitroscribeApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Vitroscribe", systemImage: "waveform") {
            ContentView()
                .frame(width: 800, height: 600)
                .background(VisualEffectView().ignoresSafeArea())
                .onReceive(AudioEngineManager.shared.$isRecording) { isRecording in
                    RecordingOverlayManager.shared.updateVisibility(isRecording: isRecording)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup initial logger, audio, etc.
        Logger.shared.log("Vitroscribe launched.")
        
        // Initialize services so listeners/timers start and notifications register
        _ = MeetingDetector.shared
        _ = GoogleCalendarService.shared
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
