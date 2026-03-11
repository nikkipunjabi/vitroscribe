import SwiftUI

struct SettingsView: View {
    @ObservedObject var authManager = GoogleAuthManager.shared
    @ObservedObject var calService = GoogleCalendarService.shared
    @ObservedObject var audioManager = AudioEngineManager.shared
    @State private var isLaunchAtStartupEnabled: Bool = StartupManager.shared.isLaunchAtStartupEnabled()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Launch at Startup", isOn: $isLaunchAtStartupEnabled)
                    .onChange(of: isLaunchAtStartupEnabled) { newValue in
                        StartupManager.shared.setLaunchAtStartup(newValue)
                    }
                
                Toggle("Show Recording Icon on Screen Share", isOn: $audioManager.isOverlayShared)
                    .help("If disabled, the red recording icon will be invisible to others when you share your screen.")
                
                Toggle("Show 'Join Meeting' HUD on Screen Share", isOn: $audioManager.isJoinPromptShared)
                    .help("If disabled, the meeting join prompt will be invisible to others during your screen share.")
                
                Divider().padding(.vertical, 5)
                
                Text("Google Calendar Integration")
                    .font(.headline)
                
                if authManager.isConnected {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected: \(authManager.connectedEmail)")
                    }
                    
                    Button("Disconnect") {
                        authManager.disconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    if !calService.upcomingEvents.isEmpty {
                        Text("Upcoming Events (\(calService.upcomingEvents.count))")
                            .font(.subheadline)
                            .padding(.top, 10)
                        
                        List(calService.upcomingEvents.prefix(10)) { event in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(event.summary ?? "No Title")
                                        .fontWeight(.medium)
                                    if let start = event.startDate {
                                        Text(start.formatted())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if let link = event.hangoutLink, let url = URL(string: link) {
                                    Button(action: {
                                        NSWorkspace.shared.open(url)
                                    }) {
                                        Label("Join", systemImage: "video.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(8)
                    }
                } else {
                    Text("Connect your Google Calendar to see upcoming meetings and get intelligent notifications before they start.")
                        .foregroundColor(.secondary)
                    
                    Button("Connect Google Calendar") {
                        authManager.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
    }
}
