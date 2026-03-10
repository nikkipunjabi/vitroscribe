import Foundation
import SQLite
import os.log

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private let transcriptsTable = Table("Transcripts")
    
    // Columns
    private let id = Expression<Int64>("id")
    private let sessionId = Expression<String>("sessionId")
    private let timestamp = Expression<Double>("timestamp")
    private let createdAt = Expression<Double>("createdAt")
    private let text = Expression<String>("text")
    private let speaker = Expression<String?>("speaker")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let folderURL = appSupportURL.appendingPathComponent("com.gravitas.Vitroscribe")
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            let dbURL = folderURL.appendingPathComponent("vitroscribe.sqlite3")
            db = try Connection(dbURL.path)
            
            let currentVersion = try db?.scalar("PRAGMA user_version") as? Int64 ?? 0
            Logger.shared.log("Current Database Version: \(currentVersion)")
            
            if currentVersion < 12 {
                // Version 12: Ensure table exists with UNIQUE sessionId and createdAt column
                // We'll rename old table if it exists and migrate data to be safe, 
                // but for v11.2 -> v12, a drop and recreate is acceptable if we want absolute integrity.
                // However, let's try to preserve v11.2 data if it has any.
                
                try db?.execute("PRAGMA foreign_keys = OFF;")
                
                // 1. Create new table with correct schema
                try db?.run(transcriptsTable.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(sessionId, unique: true) 
                    t.column(timestamp)
                    t.column(createdAt)
                    t.column(text)
                    t.column(speaker)
                })
                
                // 2. Check if we need to add createdAt column to existing table (if it wasn't recreated)
                let columns = try db?.prepare("PRAGMA table_info(Transcripts)")
                var hasCreatedAt = false
                if let columns = columns {
                    for column in columns {
                        if (column[1] as? String) == "createdAt" {
                            hasCreatedAt = true
                            break
                        }
                    }
                }
                
                if !hasCreatedAt {
                    try db?.run(transcriptsTable.addColumn(createdAt, defaultValue: Date().timeIntervalSince1970))
                    Logger.shared.log("Added createdAt column to Transcripts table.")
                }
                
                // 3. Ensure UNIQUE index exists (SQLite.swift unique: true sometimes maps to an index)
                try db?.execute("CREATE UNIQUE INDEX IF NOT EXISTS index_transcripts_on_sessionId ON Transcripts (sessionId);")
                
                try db?.run("PRAGMA user_version = 12")
                Logger.shared.log("Database migrated to version 12.")
            }
            
            Logger.shared.log("Database initialized at \(dbURL.path)")
        } catch {
            Logger.shared.log("Failed to initialize database: \(error.localizedDescription)")
        }
    }
    
    func saveOrUpdateSession(sessionId: String, text: String, speaker: String? = nil) {
        guard let db = db else { return }
        do {
            // Use a proper UPSERT-like logic to preserve createdAt
            let existing = transcriptsTable.filter(self.sessionId == sessionId)
            if try db.scalar(existing.count) > 0 {
                // Update
                try db.run(existing.update(
                    self.timestamp <- Date().timeIntervalSince1970,
                    self.text <- text,
                    self.speaker <- speaker
                ))
            } else {
                // Insert
                let now = Date().timeIntervalSince1970
                try db.run(transcriptsTable.insert(
                    self.sessionId <- sessionId,
                    self.timestamp <- now,
                    self.createdAt <- now,
                    self.text <- text,
                    self.speaker <- speaker
                ))
            }
        } catch {
            Logger.shared.log("Failed to insert/update transcript: \(error.localizedDescription)")
        }
    }
    
    struct SessionMetadata: Identifiable, Hashable {
        let id: String
        let createdAt: Date
    }
    
    func getAllSessionsMetadata() -> [SessionMetadata] {
        guard let db = db else { return [] }
        var sessions: [SessionMetadata] = []
        do {
            // Sort by createdAt descending
            let query = transcriptsTable.select(sessionId, createdAt).order(createdAt.desc)
            for row in try db.prepare(query) {
                let idValue = row[sessionId]
                let createdDate = Date(timeIntervalSince1970: row[createdAt])
                
                // Deduplicate by sessionId in memory if the DB somehow has dupes (integrity belt-and-suspenders)
                if !sessions.contains(where: { $0.id == idValue }) {
                    sessions.append(SessionMetadata(id: idValue, createdAt: createdDate))
                }
            }
        } catch {
            Logger.shared.log("Failed to fetch session metadata: \(error.localizedDescription)")
        }
        return sessions
    }
    
    func getAllSessions() -> [String] {
        return getAllSessionsMetadata().map { $0.id }
    }
    
    func getTranscript(for sessionId: String) -> String {
        guard let db = db else { return "" }
        do {
            let query = transcriptsTable.filter(self.sessionId == sessionId)
            if let row = try db.pluck(query) {
                return row[text].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            Logger.shared.log("Failed to fetch transcript for session \(sessionId): \(error.localizedDescription)")
        }
        return ""
    }
    
    func deleteSession(sessionId: String) {
        guard let db = db else { return }
        do {
            let session = transcriptsTable.filter(self.sessionId == sessionId)
            try db.run(session.delete())
            Logger.shared.log("Deleted session: \(sessionId)")
        } catch {
            Logger.shared.log("Failed to delete session \(sessionId): \(error.localizedDescription)")
        }
    }
    
    func deleteAllSessions() {
        guard let db = db else { return }
        do {
            try db.run(transcriptsTable.delete())
            Logger.shared.log("All sessions deleted from database.")
        } catch {
            Logger.shared.log("Failed to delete all sessions: \(error.localizedDescription)")
        }
    }
}
