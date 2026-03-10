import SwiftUI
import AppKit

class PromptOverlayWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 120),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.ignoresMouseEvents = false
        self.animationBehavior = .utilityWindow
        
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 370
            let y = screen.visibleFrame.maxY - 140
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.contentView = NSHostingView(rootView: PromptOverlayView())
    }
}

struct PromptOverlayView: View {
    @ObservedObject var promptManager = PromptOverlayManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.white)
                Text("Meeting Detected")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    promptManager.hide()
                    Logger.shared.log("User dismissed prompt overlay.")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            Text("Would you like Vitroscribe to start recording?")
                .font(.subheadline)
                .foregroundColor(.white)
            
            HStack {
                Spacer()
                Button("No, thanks") {
                    promptManager.hide()
                    Logger.shared.log("User declined recording from overlay.")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Yes, Start") {
                    promptManager.hide()
                    AudioEngineManager.shared.startRecording(manual: false)
                    Logger.shared.log("User accepted recording from overlay.")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(radius: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
        .onAppear {
            NSSound(named: "Glass")?.play()
        }
    }
}

class PromptOverlayManager: ObservableObject {
    static let shared = PromptOverlayManager()
    private var window: PromptOverlayWindow?
    
    func show() {
        DispatchQueue.main.async {
            if self.window == nil {
                self.window = PromptOverlayWindow()
            }
            self.window?.alphaValue = 0
            self.window?.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window?.animator().alphaValue = 1.0
            }, completionHandler: nil)
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.window?.animator().alphaValue = 0.0
            }, completionHandler: {
                self.window?.orderOut(nil)
            })
        }
    }
}
