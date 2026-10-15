import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-minimap/specs/platform-shells/spec.md:
// Minimap moves the camera, Minimap toggle, Minimap layout.

@MainActor
private func makeSession() -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 40, height: 20, fill: .grass, seed: 1))
    session.world.camera = Camera(centerX: 10, centerY: 10, zoom: 1.5)
    return session
}

private let minimapSize = CGSize(width: 240, height: 120)

@MainActor
@Test("scenario: Tap centers the camera")
func scenarioTapCentersTheCamera() {
    let session = makeSession()
    let projection = MinimapProjection(mapWidth: 40, mapHeight: 20, size: minimapSize)
    session.centerCamera(onMinimapPoint: projection.point(tileX: 30, tileY: 12), projection: projection, animated: false)
    #expect(abs(session.world.camera.centerX - 30) < 1e-9)
    #expect(abs(session.world.camera.centerY - 12) < 1e-9)
    #expect(session.world.camera.zoom == 1.5)
    #expect(session.cameraGlide == nil)
}

@MainActor
@Test("scenario: Tap glides without Reduce Motion")
func scenarioTapGlidesWithoutReduceMotion() {
    let session = makeSession()
    session.beginCameraGlide(toX: 30, y: 12, now: 0)
    #expect(session.world.camera.centerX == 10, "the glide starts where the camera is")
    session.stepCameraGlide(now: 0.1)
    let camera = session.world.camera
    #expect(camera.centerX > 10 && camera.centerX < 30)
    #expect(camera.centerY > 10 && camera.centerY < 12)
    #expect(session.cameraGlide != nil)
    session.stepCameraGlide(now: 0.25)
    #expect(session.world.camera.centerX == 30 && session.world.camera.centerY == 12)
    #expect(session.cameraGlide == nil, "the glide ends at its target")
}

@MainActor
@Test("A pan during a glide stops the glide")
func panStopsGlide() {
    let session = makeSession()
    session.beginCameraGlide(toX: 30, y: 12, now: 0)
    session.handlePanDelta(deltaX: 10, deltaY: 0)
    #expect(session.cameraGlide == nil)
}

@MainActor
@Test("scenario: Point off the map clamps")
func scenarioPointOffTheMapClamps() {
    let session = makeSession()
    let projection = MinimapProjection(mapWidth: 40, mapHeight: 20, size: minimapSize)
    let leftCorner = projection.point(tileX: 0, tileY: 19)
    session.centerCamera(
        onMinimapPoint: CGPoint(x: leftCorner.x - 20, y: leftCorner.y), projection: projection, animated: false
    )
    #expect(session.world.camera.centerX >= 0)
    #expect(session.world.camera.centerY <= 19)
}

@Test("scenario: Minimap shown by default on iPad and Mac")
func scenarioMinimapShownByDefaultOnIPadAndMac() throws {
    let suite = "minimap-default-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(MinimapPreference(defaults: defaults, idiom: .pad).isShown)
    #expect(MinimapPreference(defaults: defaults, idiom: .mac).isShown)
    #expect(!MinimapPreference(defaults: defaults, idiom: .phone).isShown)
}

@Test("scenario: Hiding the minimap persists")
func scenarioHidingTheMinimapPersists() throws {
    let suite = "minimap-hide-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    MinimapPreference(defaults: defaults, idiom: .mac).isShown = false
    #expect(!MinimapPreference(defaults: defaults, idiom: .mac).isShown)
    MinimapPreference(defaults: defaults, idiom: .phone).isShown = true
    #expect(MinimapPreference(defaults: defaults, idiom: .phone).isShown, "a phone player's choice to show it holds")
}

@Test("scenario: Mac minimap hotkey")
func scenarioMacMinimapHotkey() {
    #expect(MinimapLayout.hotkey == "m")
}

@Test("scenario: Minimap corner per dock")
func scenarioMinimapCornerPerDock() {
    let landscape = HUDLayout.make(size: CGSize(width: 1180, height: 820), idiom: .pad)
    let portrait = HUDLayout.make(size: CGSize(width: 390, height: 844), idiom: .phone)
    #expect(MinimapLayout.corner(for: landscape) == .bottomTrailing)
    #expect(MinimapLayout.corner(for: portrait) == .topTrailing)
}

@Test("scenario: Minimap size per idiom")
func scenarioMinimapSizePerIdiom() {
    #expect(MinimapLayout.mapSize(for: .phone) == CGSize(width: 144, height: 72))
    #expect(MinimapLayout.mapSize(for: .pad) == CGSize(width: 224, height: 112))
    #expect(MinimapLayout.mapSize(for: .mac) == CGSize(width: 240, height: 120))
}

@Test("scenario: Callout avoids the minimap")
func scenarioCalloutAvoidsTheMinimap() {
    let size = CGSize(width: 1180, height: 820)
    let layout = HUDLayout.make(size: size, idiom: .pad)
    let insets = EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
    let free = InspectorCalloutLayout.freeArea(size: size, insets: insets, layout: layout, showsMinimap: true)
    let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
    #expect(free.maxY < minimap.minY)
    let without = InspectorCalloutLayout.freeArea(size: size, insets: insets, layout: layout, showsMinimap: false)
    #expect(without.maxY > minimap.minY, "the band is only left out while the minimap shows")

    let phone = HUDLayout.make(size: CGSize(width: 390, height: 844), idiom: .phone)
    let phoneSize = CGSize(width: 390, height: 844)
    let phoneFree = InspectorCalloutLayout.freeArea(size: phoneSize, insets: insets, layout: phone, showsMinimap: true)
    #expect(phoneFree.minY > MinimapLayout.frame(in: phoneSize, insets: insets, layout: phone).maxY)
}
