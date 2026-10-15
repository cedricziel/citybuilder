import CityCore
import Foundation
import SwiftUI

/// Where the title camera looks and what time of day it shows, as a pure
/// function of the seconds since the title appeared. Spec:
/// `platform-shells` / Title screen shows the island.
struct TitleBackdropMotion: Sendable {
    /// One slow day (morning to evening) and one quick night, in seconds.
    static let dayDuration = 150.0
    static let nightDuration = 10.0
    static let lightCycle = dayDuration + nightDuration
    static let morning = 0.30
    static let evening = 0.82
    /// The time of day held under Reduce Motion: mid-morning.
    static let stillFraction = 0.45

    let center: Camera
    let reduceMotion: Bool

    /// A slow Lissajous drift, at most 3.9 tiles from the town center,
    /// with a faint zoom breath. Coprime periods keep it from looping soon.
    func camera(at elapsed: Double) -> Camera {
        guard !reduceMotion else { return center }
        let turn = 2 * Double.pi * elapsed
        return Camera(
            centerX: center.centerX + 3.0 * sin(turn / 97),
            centerY: center.centerY + 2.5 * sin(turn / 131),
            zoom: center.zoom * (1 + 0.04 * sin(turn / 157))
        )
    }

    /// A tick whose `TimeOfDay` follows the time-lapse. It only grows, so
    /// residents keep walking forward.
    func tickCount(at elapsed: Double) -> UInt64 {
        let ticksPerDay = Double(TimeOfDay.ticksPerDay)
        guard !reduceMotion else {
            return UInt64(((Self.stillFraction - TimeOfDay.startFraction) * ticksPerDay).rounded())
        }
        let time = max(elapsed, 0)
        let cycles = (time / Self.lightCycle).rounded(.down)
        let within = time.truncatingRemainder(dividingBy: Self.lightCycle)
        let daylight = Self.evening - Self.morning
        let progress = within < Self.dayDuration
            ? daylight * within / Self.dayDuration
            : daylight + (1 - daylight) * (within - Self.dayDuration) / Self.nightDuration
        // Tick 0 reads `TimeOfDay.startFraction`; shift so cycle 0 starts at morning.
        let morningTick = (Self.morning - TimeOfDay.startFraction + 1) * ticksPerDay
        return UInt64((morningTick + (cycles + progress) * ticksPerDay).rounded())
    }
}

/// The starting island behind the title menu, drawn by the registered
/// world renderer with a drifting camera and a time-lapse sky. Without a
/// renderer (tests, previews) it is a warm gradient. `active` false drops
/// the scene, so it stops drawing while a sheet covers the title.
struct TitleBackdrop: View {
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapshot: WorldSnapshot?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.19, blue: 0.27), Color(red: 0.52, green: 0.39, blue: 0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            if active, let snapshot, let factory = SnapshotRendererRegistry.shared.factory {
                world(snapshot, factory: factory)
                    .id(reduceMotion)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: snapshot != nil)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard snapshot == nil, SnapshotRendererRegistry.shared.factory != nil else { return }
            snapshot = await Task.detached(priority: .utility) { Self.island }.value
        }
    }

    private func world(_ snapshot: WorldSnapshot, factory: SnapshotRendererRegistry.Factory) -> some View {
        let motion = TitleBackdropMotion(center: snapshot.camera, reduceMotion: reduceMotion)
        let origin = Date.now
        return factory(
            {
                let elapsed = Date.now.timeIntervalSince(origin)
                var frame = snapshot
                frame.camera = motion.camera(at: elapsed)
                frame.tickCount = motion.tickCount(at: elapsed)
                return frame
            },
            { _ in }, { _ in }, { _ in }, { _ in }, { nil }, { nil }, { nil }
        )
    }

    /// Built once, on first use: the world is deterministic.
    nonisolated static let island = makeSnapshot()

    /// The default island with finished houses, under the new-game camera
    /// (on the town center), zoomed in a little. Generating it ticks the
    /// sim, so callers keep it off the main thread.
    nonisolated static func makeSnapshot() -> WorldSnapshot {
        var world = UITestSeed.townWorld(houses: 6)
        world.camera.setZoom(1.2)
        return world.snapshot()
    }
}
