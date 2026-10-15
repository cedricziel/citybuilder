#if os(tvOS)
import GameController
import QuartzCore
import SwiftUI
import UIKit

/// Hosts the Apple TV map's input: a focusable view inside a
/// `GCEventViewController`. While the map has focus, presses and
/// controller input reach `TVRemoteController` and never the focus
/// engine; while the HUD has focus, the focus engine owns the remote.
/// Design D3, task 2.12.
struct TVMapInputHost: UIViewControllerRepresentable {
    let remote: TVRemoteController

    func makeUIViewController(context _: Context) -> TVMapInputController {
        TVMapInputController(remote: remote)
    }

    func updateUIViewController(_: TVMapInputController, context _: Context) {}
}

/// The map's focus target. It takes focus only while the map owns input.
final class TVMapFocusView: UIView {
    var acceptsFocus = true
    /// Called when the map gains or loses focus, including moves the
    /// system makes, such as a sheet taking focus or giving it back.
    var onFocusChange: ((Bool) -> Void)?

    override var canBecomeFocused: Bool {
        acceptsFocus
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedItem === self {
            onFocusChange?(true)
        } else if context.previouslyFocusedItem === self {
            onFocusChange?(false)
        }
    }
}

final class TVMapInputController: GCEventViewController {
    private let remote: TVRemoteController
    private let mapView = TVMapFocusView()
    private var displayLink: CADisplayLink?
    private var connectObserver: NSObjectProtocol?

    init(remote: TVRemoteController) {
        self.remote = remote
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = mapView
        mapView.backgroundColor = .clear
        mapView.isAccessibilityElement = true
        mapView.accessibilityIdentifier = "tv.map"
        mapView.accessibilityLabel = "Map"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        controllerUserInteractionEnabled = false
        remote.applyEffect = { [weak self] effect in
            self?.apply(effect)
        }
        mapView.onFocusChange = { [weak self] focused in
            self?.remote.focusMoved(toMap: focused, at: CACurrentMediaTime())
        }
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.attachControllers() }
        }
        attachControllers()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        focusMap()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [mapView]
    }

    @objc private func tick(_ link: CADisplayLink) {
        remote.send(.tick, at: link.timestamp)
    }

    // MARK: Focus handover (task 2.13)

    private func apply(_ effect: RemoteEffect) {
        switch effect {
        case .focusMap:
            focusMap()
        case .focusHUD, .focusInspector:
            focusHUD()
        }
    }

    /// Requested on the next run-loop turn, after SwiftUI restores focus
    /// to the control that closed a drawer or a menu.
    private func focusMap() {
        mapView.acceptsFocus = true
        controllerUserInteractionEnabled = false
        DispatchQueue.main.async { [mapView] in
            UIFocusSystem.focusSystem(for: mapView)?.requestFocusUpdate(to: mapView)
        }
    }

    /// The map stops taking focus, so the focus engine moves it to the
    /// HUD's preferred control.
    private func focusHUD() {
        mapView.acceptsFocus = false
        controllerUserInteractionEnabled = true
        guard let window = view.window else { return }
        UIFocusSystem.focusSystem(for: window)?.requestFocusUpdate(to: window)
    }

    // MARK: UIKit presses (the simulator's remote, and keyboards)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled: Set<UIPress> = []
        for press in presses {
            if let input = Self.input(began: press.type) {
                remote.sendUIKit(input, at: press.timestamp)
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled: Set<UIPress> = []
        for press in presses {
            if let input = Self.input(ended: press.type) {
                remote.sendUIKit(input, at: press.timestamp)
            } else if Self.input(began: press.type) == nil {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesEnded(unhandled, with: event)
        }
    }

    private static func input(began type: UIPress.PressType) -> RemoteInput? {
        switch type {
        case .upArrow: .click(.up)
        case .rightArrow: .click(.right)
        case .downArrow: .click(.down)
        case .leftArrow: .click(.left)
        case .select: .selectDown
        case .playPause: .playPauseDown
        case .menu: .back
        default: nil
        }
    }

    private static func input(ended type: UIPress.PressType) -> RemoteInput? {
        switch type {
        case .select: .selectUp
        case .playPause: .playPauseUp
        default: nil
        }
    }

    // MARK: GameController (the Siri Remote's touch surface, controllers)

    private func attachControllers() {
        for controller in GCController.controllers() {
            if let gamepad = controller.extendedGamepad {
                gamepad.valueChangedHandler = { [weak self] gamepad, _ in
                    MainActor.assumeIsolated { self?.send(Self.snapshot(of: gamepad)) }
                }
            } else if let remoteProfile = controller.microGamepad {
                remoteProfile.reportsAbsoluteDpadValues = true
                remoteProfile.allowsRotation = false
                remoteProfile.valueChangedHandler = { [weak self] profile, _ in
                    MainActor.assumeIsolated { self?.send(Self.snapshot(of: profile)) }
                }
            }
        }
    }

    private func send(_ snapshot: ControllerSnapshot) {
        remote.send(snapshot, at: CACurrentMediaTime())
    }

    private func send(_ snapshot: RemoteSnapshot) {
        remote.send(snapshot, at: CACurrentMediaTime())
    }

    private static func snapshot(of gamepad: GCExtendedGamepad) -> ControllerSnapshot {
        let dpad: RemoteDirection? = if gamepad.dpad.up.isPressed {
            .up
        } else if gamepad.dpad.right.isPressed {
            .right
        } else if gamepad.dpad.down.isPressed {
            .down
        } else if gamepad.dpad.left.isPressed {
            .left
        } else {
            nil
        }
        return ControllerSnapshot(
            leftStick: (Double(gamepad.leftThumbstick.xAxis.value), Double(gamepad.leftThumbstick.yAxis.value)),
            dpad: dpad,
            buttonA: gamepad.buttonA.isPressed,
            buttonB: gamepad.buttonB.isPressed,
            buttonY: gamepad.buttonY.isPressed,
            menu: gamepad.buttonMenu.isPressed,
            leftTrigger: Double(gamepad.leftTrigger.value),
            rightTrigger: Double(gamepad.rightTrigger.value)
        )
    }

    private static func snapshot(of profile: GCMicroGamepad) -> RemoteSnapshot {
        let x = Double(profile.dpad.xAxis.value)
        let y = Double(profile.dpad.yAxis.value)
        return RemoteSnapshot(
            touch: x == 0 && y == 0 ? nil : (x, y),
            pressed: profile.buttonA.isPressed,
            playPause: profile.buttonX.isPressed,
            menu: profile.buttonMenu.isPressed
        )
    }
}
#endif
