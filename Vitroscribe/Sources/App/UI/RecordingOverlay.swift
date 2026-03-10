import SwiftUI
import AppKit

class RecordingOverlayWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 44),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
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
        
        // Hide from screen sharing by default
        updatePrivacySetting()
        
        // Position at top-right by default
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 140
            let y = screen.visibleFrame.maxY - 60
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.contentView = NSHostingView(rootView: OverlayView())
    }
    
    func updatePrivacySetting() {
        let isShared = AudioEngineManager.shared.isOverlayShared
        if isShared {
            self.sharingType = .readOnly
        } else {
            self.sharingType = .none
        }
    }
}

struct OverlayView: View {
    @ObservedObject private var audioManager = AudioEngineManager.shared
    @State private var isPulsing = false
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            if isHovering {
                Button(action: {
                    audioManager.stopRecording()
                }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            }
            
            Text(isHovering ? "STOP" : "REC")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 80)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Capsule()
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
        )
        .onAppear {
            isPulsing = true
        }
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovering = hovering
            }
        }
    }
}

class RecordingOverlayManager: ObservableObject {
    static let shared = RecordingOverlayManager()
    private var window: RecordingOverlayWindow?
    
    func show() {
        DispatchQueue.main.async {
            if self.window == nil {
                self.window = RecordingOverlayWindow()
            }
            self.window?.orderFrontRegardless()
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
        }
    }
    
    func updateVisibility(isRecording: Bool) {
        if isRecording {
            show()
        } else {
            hide()
        }
    }
    
    func updatePrivacySetting() {
        DispatchQueue.main.async {
            self.window?.updatePrivacySetting()
        }
    }
}
