import CityCore
import Foundation

extension GameSession {
    /// Tells the shell a step ran, and when it crossed into a new season.
    func notifyAutosaveHooks(after events: [WorldEvent]) {
        if events.contains(where: { if case .seasonChanged = $0 { true } else { false } }) {
            onSeasonChange?()
        }
        onPlayStep?()
    }

    /// The autosave went wrong: say so through the session banner. The
    /// previous save is untouched.
    public func noteAutosaveFailed() {
        let banner = SessionBanner(
            title: GameText.string("banner.autosaveFailed.title"),
            description: GameText.string("banner.autosaveFailed.text")
        )
        guard bannerState?.banner != banner, !bannerQueue.contains(where: { $0.banner == banner }) else { return }
        bannerQueue.append(QueuedBanner(banner: banner, isUrgent: false, expiresAtTick: nil))
    }

    /// "Autosaved 2 minutes ago", or nil before the first autosave.
    func autosaveLine(now: Date = Date()) -> String? {
        guard let lastAutosave else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Language.current.locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        let elapsed = max(now.timeIntervalSince(lastAutosave), 0)
        let ago = elapsed < 60
            ? formatter.localizedString(fromTimeInterval: 0)
            : formatter.localizedString(for: lastAutosave, relativeTo: now)
        return GameText.string("pause.autosaved", ago)
    }
}
