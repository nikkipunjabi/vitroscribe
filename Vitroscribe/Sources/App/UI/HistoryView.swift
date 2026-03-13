import SwiftUI

struct HistoryView: View {
    @State private var sessions: [DatabaseManager.SessionMetadata] = []
    @State private var selectedSessionId: String?
    @State private var currentTranscriptText: String = ""
    @State private var isSidebarVisible: Bool = true
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    @State private var isEditingTitle = false
    @State private var newTitle = ""
    
    // Search and Pagination
    @State private var searchText = ""
    @State private var filterDate: Date? = nil
    @State private var hasMoreSessions = true
    private let pageSize = 20
    @State private var isShowingDatePicker = false
    
    private func durationString(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "" }
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Sidebar
            if isSidebarVisible {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search transcripts...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: { isShowingDatePicker.toggle() }) {
                            Image(systemName: filterDate == nil ? "calendar" : "calendar.badge.minus")
                                .foregroundColor(filterDate == nil ? .secondary : .blue)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $isShowingDatePicker) {
                            VStack {
                                DatePicker("Filter by Date", selection: Binding(
                                    get: { filterDate ?? Date() },
                                    set: { filterDate = $0; isShowingDatePicker = false }
                                ), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                                
                                if filterDate != nil {
                                    Button("Clear Date Filter") {
                                        filterDate = nil
                                        isShowingDatePicker = false
                                    }
                                    .padding(.bottom)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    List(selection: $selectedSessionId) {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title ?? dateFormatter.string(from: session.createdAt))
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                HStack {
                                    if let start = session.plannedStartTime, let end = session.plannedEndTime {
                                        Text("\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))")
                                    } else {
                                        Text(timeFormatter.string(from: session.createdAt))
                                    }
                                    
                                    Text("•")
                                    
                                    Text(dateFormatter.string(from: session.createdAt))
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                let dur = durationString(session.recordingDuration)
                                if !dur.isEmpty {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        Text(dur)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary.opacity(0.8))
                                }

                            }
                            .padding(.vertical, 4)
                            .tag(session.id)
                            .contextMenu {
                                Button {
                                    startRenaming(session)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteSession(session.id)
                                } label: {
                                    Label("Delete Session", systemImage: "trash")
                                }
                            }
                        }
                        
                        if hasMoreSessions && !sessions.isEmpty {
                            Button(action: loadMoreSessions) {
                                Text("Load More")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
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
                .frame(width: 250)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            // Decorative Divider that only shows when sidebar is there
            if isSidebarVisible {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 1)
                    .ignoresSafeArea()
            }
            
            // MARK: - Detail View
            VStack(alignment: .leading) {
                if let selectedId = selectedSessionId,
                   let selectedSession = sessions.first(where: { $0.id == selectedId }) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            // Primary Editable Headline: Title or Date
                            HStack(spacing: 8) {
                                Text(selectedSession.title ?? "\(dateFormatter.string(from: selectedSession.createdAt)) \(timeFormatter.string(from: selectedSession.createdAt))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Button(action: { startRenaming(selectedSession) }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $isEditingTitle) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Rename Session")
                                            .font(.headline)
                                        TextField("Enter new title", text: $newTitle)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 200)
                                        
                                        HStack {
                                            Button("Cancel") { isEditingTitle = false }
                                            Spacer()
                                            Button("Save") {
                                                saveNewTitle(for: selectedId)
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }
                                    .padding()
                                }
                            }
                            
                            // Static Label
                            Text("Meeting Transcript")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            // Always show session date/time context
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(dateFormatter.string(from: selectedSession.createdAt)) at \(timeFormatter.string(from: selectedSession.createdAt))")
                                
                                if let start = selectedSession.plannedStartTime, let end = selectedSession.plannedEndTime {
                                    Text("\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))")
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                                
                                let dur = durationString(selectedSession.recordingDuration)
                                if !dur.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                        Text("Recording duration: \(dur)")
                                    }
                                    .foregroundColor(.green.opacity(0.85))
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        }
                        Spacer()
                        
                        HStack {
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
                    }
                    .padding(.bottom, 15)
                    
                    ScrollView {
                        Text(highlightedTranscript)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                            .textSelection(.enabled)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSidebarVisible.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .help("Toggle Sidebar")
                }
            }
        }
        .onChange(of: selectedSessionId) { newValue in
            if let sessionId = newValue {
                loadTranscript(for: sessionId)
            }
        }
        .onChange(of: searchText) { _ in
            refreshSessions()
        }
        .onChange(of: filterDate) { _ in
            refreshSessions()
        }
        .onAppear(perform: refreshSessions)
    }
    
    private func refreshSessions() {
        sessions = DatabaseManager.shared.getSessionsMetadata(
            limit: pageSize,
            offset: 0,
            searchText: searchText,
            filterDate: filterDate
        )
        hasMoreSessions = sessions.count >= pageSize
    }
    
    private func loadMoreSessions() {
        let newSessions = DatabaseManager.shared.getSessionsMetadata(
            limit: pageSize,
            offset: sessions.count,
            searchText: searchText,
            filterDate: filterDate
        )
        sessions.append(contentsOf: newSessions)
        hasMoreSessions = newSessions.count >= pageSize
    }
    
    private func loadSessions() {
        refreshSessions()
    }
    
    private var highlightedTranscript: AttributedString {
        let text = currentTranscriptText
        var attributedString = AttributedString(text)
        
        let search = searchText.trimmingCharacters(in: .whitespaces)
        guard !search.isEmpty else { return attributedString }
        
        var start = text.startIndex
        while start < text.endIndex {
            if let range = text.range(of: search, options: .caseInsensitive, range: start..<text.endIndex) {
                if let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].backgroundColor = .yellow
                    attributedString[attrRange].foregroundColor = .black
                    attributedString[attrRange].font = .system(size: 14, weight: .bold)
                }
                start = range.upperBound
            } else {
                break
            }
        }
        
        return attributedString
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
    
    private func startRenaming(_ session: DatabaseManager.SessionMetadata) {
        newTitle = session.title ?? dateFormatter.string(from: session.createdAt)
        isEditingTitle = true
    }
    
    private func saveNewTitle(for sessionId: String) {
        DatabaseManager.shared.updateSessionTitle(sessionId: sessionId, newTitle: newTitle)
        isEditingTitle = false
        loadSessions()
    }
}
