import CityCore
import SwiftUI
import Testing
@testable import CityUI

private let townCenter = Camera(centerX: 40.5, centerY: 30.5, zoom: 1.2)

private func distance(_ camera: Camera, from center: Camera) -> Double {
    let dx = camera.centerX - center.centerX
    let dy = camera.centerY - center.centerY
    return (dx * dx + dy * dy).squareRoot()
}

private func fraction(_ motion: TitleBackdropMotion, at elapsed: Double) -> Double {
    TimeOfDay(tick: motion.tickCount(at: elapsed)).fraction
}

@Test("scenario: title camera drifts around the town center")
func titleCameraDrifts() {
    let motion = TitleBackdropMotion(center: townCenter, reduceMotion: false)
    let cameras = [0.0, 20, 300].map { motion.camera(at: $0) }
    #expect(Set(cameras.map(\.centerX)).count == 3)
    #expect(Set(cameras.map(\.centerY)).count == 3)
    for elapsed in stride(from: 0.0, through: 1200, by: 7) {
        #expect(distance(motion.camera(at: elapsed), from: townCenter) <= 4)
    }
}

@Test("scenario: title light moves from morning to evening")
func titleLightMovesThroughTheDay() {
    let motion = TitleBackdropMotion(center: townCenter, reduceMotion: false)
    #expect(abs(fraction(motion, at: 0) - 0.30) < 0.002)
    #expect(fraction(motion, at: 145) > 0.8)
    #expect(abs(fraction(motion, at: 160) - 0.30) < 0.002)
    var previous = motion.tickCount(at: 0)
    for elapsed in stride(from: 0.5, through: 640, by: 0.5) {
        let tick = motion.tickCount(at: elapsed)
        #expect(tick >= previous)
        previous = tick
    }
    #expect(motion.tickCount(at: 160) > motion.tickCount(at: 145))
}

@Test("scenario: title night passes quickly")
func titleNightPassesQuickly() {
    let motion = TitleBackdropMotion(center: townCenter, reduceMotion: false)
    let samples = stride(from: 0.0, to: TitleBackdropMotion.lightCycle, by: 0.1)
    let night = samples.filter { TimeOfDay(tick: motion.tickCount(at: $0)).phase == .night }
    #expect(!night.isEmpty)
    #expect(Double(night.count) * 0.1 <= 10)
}

@Test("scenario: title backdrop stands still under reduce motion")
func titleBackdropStill() {
    let motion = TitleBackdropMotion(center: townCenter, reduceMotion: true)
    for elapsed in [0.0, 300] {
        let camera = motion.camera(at: elapsed)
        #expect(camera.centerX == townCenter.centerX)
        #expect(camera.centerY == townCenter.centerY)
        #expect(abs(fraction(motion, at: elapsed) - 0.45) < 0.002)
    }
}

@MainActor
@Test("scenario: title backdrop without a renderer")
func titleBackdropWithoutRenderer() {
    #expect(SnapshotRendererRegistry().factory == nil)
}

@Test func titleBackdropSnapshotCentersOnTheTown() {
    let snapshot = TitleBackdrop.makeSnapshot()
    let newGame = World.newGame(layout: .singleIsland, seed: 0).camera
    #expect(snapshot.camera.centerX == newGame.centerX)
    #expect(snapshot.camera.centerY == newGame.centerY)
    #expect(snapshot.camera.zoom == 1.2)
    #expect(snapshot.roadDisconnectedBuildings.isEmpty)
    #expect(snapshot.buildings.values.contains { $0.kind == .house && $0.state == .operational })
}

@Test("scenario: menu items enter in order")
func menuItemsEnterInOrder() {
    #expect(MenuEntrance.delay(index: 0) == 0)
    #expect(abs(MenuEntrance.delay(index: 3) - 0.24) < 1e-9)
    #expect(MenuEntrance.offset(entered: false, reduceMotion: false) == 16)
    #expect(MenuEntrance.offset(entered: true, reduceMotion: false) == 0)
    #expect(MenuEntrance.animation(index: 2, reduceMotion: false) != nil)
}

@Test func appleTVMenuItemsStayOpaque() {
    #expect(MenuEntrance.opacity(entered: false, reduceMotion: false, fades: true) == 0)
    #expect(MenuEntrance.opacity(entered: false, reduceMotion: false, fades: false) == 1)
    #expect(MenuEntrance.opacity(entered: true, reduceMotion: false, fades: true) == 1)
}

@Test("scenario: menu items appear at once under reduce motion")
func menuItemsAppearAtOnce() {
    for index in 0 ..< 5 {
        #expect(MenuEntrance.animation(index: index, reduceMotion: true) == nil)
    }
    #expect(MenuEntrance.offset(entered: false, reduceMotion: true) == 0)
}

@Test("scenario: pressed and hovered button scale")
func pressedAndHoveredScale() {
    #expect(TitleMenuButtonStyle.scale(pressed: true, hovered: false, reduceMotion: false) == 0.96)
    #expect(TitleMenuButtonStyle.scale(pressed: false, hovered: true, reduceMotion: false) == 1.03)
    #expect(TitleMenuButtonStyle.scale(pressed: false, hovered: false, reduceMotion: false) == 1)
}

@Test("scenario: pressed button under reduce motion")
func pressedUnderReduceMotion() {
    #expect(TitleMenuButtonStyle.scale(pressed: true, hovered: true, reduceMotion: true) == 1)
    #expect(TitleMenuButtonStyle.brightness(pressed: true, hovered: false) < 0)
}
