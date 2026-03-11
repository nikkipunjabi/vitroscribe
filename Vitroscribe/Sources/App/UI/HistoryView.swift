import SwiftUI

struct HistoryView: View {
    @State private var sessions: [DatabaseManager.SessionMetadata] = []
    @State private var selectedSessionId: String?
    @State private var currentTranscriptText: String = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationSplitView {
            VStack {
                List(sessions, selection: $selectedSessionId) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: session.createdAt))
                            .font(.headline)
                        Text("Session: \(session.id.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(session.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteSession(session.id)
                        } label: {
                            Label("Delete Session", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                Button(action: clearAll) {
                    Label("Clear All History", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            VStack(alignment: .leading) {
                if let selectedId = selectedSessionId,
                   let selectedSession = sessions.first(where: { $0.id == selectedId }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Transcript Details")
                                .font(.headline)
                            Text(dateFormatter.string(from: selectedSession.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(role: .destructive, action: {
                            deleteSession(selectedId)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button(action: copyToClipboard) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.bottom, 10)
                    
                    ScrollView {
                        Text(currentTranscriptText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Select a session to view its history.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
        .onChange(of: selectedSessionId) { newValue in
            if let sessionId = newValue {
                loadTranscript(for: sessionId)
            }
        }
        .onAppear(perform: loadSessions)
    }
    
    private func loadSessions() {
        sessions = DatabaseManager.shared.getAllSessionsMetadata()
    }
    
    private func loadTranscript(for sessionId: String) {
        currentTranscriptText = DatabaseManager.shared.getTranscript(for: sessionId)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentTranscriptText, forType: .string)
    }
    
    private func deleteSession(_ sessionId: String) {
        DatabaseManager.shared.deleteSession(sessionId: sessionId)
        if selectedSessionId == sessionId {
            selectedSessionId = nil
            currentTranscriptText = ""
        }
        loadSessions()
    }
    
    private func clearAll() {
        DatabaseManager.shared.deleteAllSessions()
        selectedSessionId = nil
        currentTranscriptText = ""
        loadSessions()
    }
}
