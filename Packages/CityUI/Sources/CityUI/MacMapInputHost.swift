#if os(macOS)
import AppKit
import SpriteKit
import SwiftUI

/// The Mac's map input while a game is on screen: Esc, the pan and zoom
/// keys, trackpad scroll and pinch, the mouse wheel, and right- or
/// middle-drag. A local event monitor, because the SpriteKit view is not
/// reliably first responder and SwiftUI has no scroll-wheel or right-drag
/// gesture. Events in a sheet, or over the HUD, pass through. Spec:
/// `platform-shells` / Esc steps back on the Mac, Mac trackpad and mouse
/// camera, Mac keyboard camera.
extension MacMapInput {
    /// Whether a scroll or pinch event continues a gesture already under
    /// way, so it keeps the target found when the gesture began. A mouse
    /// wheel notch has no phase and starts afresh.
    static func continuesGesture(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase) -> Bool {
        if !momentumPhase.isEmpty { return true }
        return !phase.isEmpty && phase.isDisjoint(with: [.began, .mayBegin])
    }

    /// The SpriteKit view a hit view belongs to, or nil when the hit lands
    /// on the HUD. SwiftUI's hosting view answers for its own controls,
    /// pills and lists, so only the map's bare area reaches the SKView.
    static func map(containing hit: NSView?) -> SKView? {
        var view = hit
        while let current = view {
            if let map = current as? SKView { return map }
            view = current.superview
        }
        return nil
    }
}

struct MacMapInputHost: NSViewRepresentable {
    let session: GameSession
    @Binding var stepBack: StepBackState

    func makeNSView(context _: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context _: Context) {
        view.session = session
        view.onEscape = { CityRootView.stepBack(session: session, state: &$stepBack.wrappedValue) }
    }

    static func dismantleNSView(_ view: MonitorView, coordinator _: ()) {
        view.stopMonitoring()
    }

    final class MonitorView: NSView {
        var session: GameSession?
        var onEscape: (() -> Void)?
        private var monitor: Any?
        private var isDragPanning = false
        /// The map under the current scroll or pinch gesture, found when
        /// it begins rather than on every event of it.
        private weak var gestureMap: SKView?

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            let types: NSEvent.EventTypeMask = [
                .keyDown, .scrollWheel, .magnify,
                .rightMouseDown, .rightMouseDragged, .rightMouseUp,
                .otherMouseDown, .otherMouseDragged, .otherMouseUp
            ]
            monitor = NSEvent.addLocalMonitorForEvents(matching: types) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        /// Returns nil for an event it used.
        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let session, let window, event.window === window, window.attachedSheet == nil else { return event }
            switch event.type {
            case .keyDown:
                return handleKey(event, session: session) ? nil : event
            case .scrollWheel:
                guard let map = gestureMap(for: event) else { return event }
                let action = MacMapInput.scroll(
                    deltaX: event.scrollingDeltaX,
                    deltaY: event.scrollingDeltaY,
                    isPrecise: event.hasPreciseScrollingDeltas,
                    isInverted: event.isDirectionInvertedFromDevice
                )
                session.apply(action, aroundScreenOffset: offset(of: event, in: map))
            case .magnify:
                guard let map = gestureMap(for: event) else { return event }
                session.zoom(by: 1 + event.magnification, aroundScreenOffset: offset(of: event, in: map))
            case .rightMouseDown, .otherMouseDown:
                isDragPanning = mapView(under: event) != nil
                return event
            case .rightMouseDragged, .otherMouseDragged:
                guard isDragPanning else { return event }
                session.apply(MacMapInput.drag(deltaX: event.deltaX, deltaY: event.deltaY))
            default:
                isDragPanning = false
                return event
            }
            return nil
        }

        private func handleKey(_ event: NSEvent, session: GameSession) -> Bool {
            guard !(window?.firstResponder is NSText) else { return false }
            let characters = event.charactersIgnoringModifiers ?? ""
            let modifiers = event.modifierFlags.intersection([.command, .control, .option])
            if modifiers == .command, let action = MacMapInput.commandKey(characters) {
                session.apply(action)
                return true
            }
            guard modifiers.isEmpty else { return false }
            if characters == "\u{1B}" {
                // Holding Esc must not run down the whole chain.
                if !event.isARepeat { onEscape?() }
                return true
            }
            guard let action = MacMapInput.key(characters, atZoom: session.world.camera.zoom) else { return false }
            session.apply(action)
            return true
        }

        /// A gesture's later and momentum events reuse the map found when
        /// it began; a mouse wheel has no phases, so each notch looks again.
        private func gestureMap(for event: NSEvent) -> SKView? {
            if !MacMapInput.continuesGesture(phase: event.phase, momentumPhase: event.momentumPhase) {
                gestureMap = mapView(under: event)
            }
            return gestureMap
        }

        /// The SpriteKit view under the event, unless the HUD covers it.
        private func mapView(under event: NSEvent) -> SKView? {
            guard let content = window?.contentView else { return nil }
            let point = content.superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
            return MacMapInput.map(containing: content.hitTest(point))
        }

        /// The event's distance from the map's center, y down.
        private func offset(of event: NSEvent, in map: NSView) -> CGSize {
            let point = map.convert(event.locationInWindow, from: nil)
            let deltaY = point.y - map.bounds.midY
            return CGSize(width: point.x - map.bounds.midX, height: map.isFlipped ? deltaY : -deltaY)
        }
    }
}
#endif
