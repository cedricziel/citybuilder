import Foundation

/// Metadata pulled from a save file's file-system attributes, without
/// decoding the encoded `World`. Used by the title screen's `Continue`
/// row and any future save-list UI. Spec: `add-title-screen-and-new-game`
/// / `persistence-save-load`.
public struct SaveMetadata: Sendable, Equatable {
    public let gameID: UUID
    public let writeDate: Date
    public let displayName: String

    public init(gameID: UUID, writeDate: Date, displayName: String) {
        self.gameID = gameID
        self.writeDate = writeDate
        self.displayName = displayName
    }
}

public extension SaveStore {
    /// Every save in the store, sorted by modification date descending
    /// (newest first). Pure file-system scan — no JSON decoding, so a
    /// corrupt save still appears here and surfaces failure only at
    /// load time.
    func listSaves() throws -> [SaveMetadata] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseDirectory.path) else { return [] }
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }
        let formatter = SaveMetadata.displayDateFormatter
        var out: [SaveMetadata] = []
        for url in entries {
            guard url.pathExtension == "json" else { continue }
            let stem = url.deletingPathExtension().lastPathComponent
            guard let id = UUID(uuidString: stem) else { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values?.contentModificationDate ?? Date.distantPast
            out.append(SaveMetadata(
                gameID: id,
                writeDate: date,
                displayName: formatter.string(from: date)
            ))
        }
        out.sort { $0.writeDate > $1.writeDate }
        return out
    }

    /// Newest save in the store, or nil when the store is empty.
    func mostRecentSave() throws -> SaveMetadata? {
        try listSaves().first
    }
}

private extension SaveMetadata {
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
