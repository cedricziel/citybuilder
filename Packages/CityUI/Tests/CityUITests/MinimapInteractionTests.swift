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
    #expect(MinimapPreference.storage(idiom: .pad, store: defaults).wrappedValue)
    #expect(MinimapPreference.storage(idiom: .mac, store: defaults).wrappedValue)
    #expect(!MinimapPreference.storage(idiom: .phone, store: defaults).wrappedValue)
}

@Test("scenario: Hiding the minimap persists")
func scenarioHidingTheMinimapPersists() throws {
    let suite = "minimap-hide-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    MinimapPreference.storage(idiom: .mac, store: defaults).wrappedValue = false
    #expect(!MinimapPreference.storage(idiom: .mac, store: defaults).wrappedValue)
    MinimapPreference.storage(idiom: .phone, store: defaults).wrappedValue = true
    #expect(MinimapPreference.storage(idiom: .phone, store: defaults).wrappedValue, "a phone player's choice to show it holds")
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

@Test("scenario: Stocks tray stays clear of the minimap", arguments: [
    (CGSize(width: 390, height: 844), HUDIdiom.phone),
    (CGSize(width: 820, height: 1180), HUDIdiom.pad),
    (CGSize(width: 320, height: 1000), HUDIdiom.pad),
    (CGSize(width: 900, height: 1000), HUDIdiom.mac)
])
func trayAvoidsTheCard(size: CGSize, idiom: HUDIdiom) {
    let layout = HUDLayout.make(size: size, idiom: idiom)
    let insets = EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
    let card = MinimapLayout.frame(in: size, insets: insets, layout: layout)
    let hudWidth = size.width - layout.margin * 2
    let column = MinimapLayout.trayColumnWidth(hudWidth: hudWidth, layout: layout, showsMinimap: true)
    for chips in [1, 4, 18] {
        let columns = StocksTrayLayout.columns(fitting: column, isPhone: layout.isPhone, chips: chips)
        // The tray is centered in its column, which starts at the margin.
        let trayMaxX = layout.margin + (column + StocksTrayLayout.width(columns: columns)) / 2
        #expect(trayMaxX <= card.minX, "\(size) with \(chips) goods")
    }
}

@MainActor
@Test("The minimap follows the camera once per frame")
func minimapFollowsTheCamera() {
    let session = makeSession()
    session.frameWillRender(now: 0)
    #expect(session.minimap.camera == session.world.camera)
    session.handlePanDelta(deltaX: 64, deltaY: 0)
    #expect(session.minimap.camera != session.world.camera, "only the frame hands the camera over")
    session.frameWillRender(now: 0)
    #expect(session.minimap.camera == session.world.camera)
}
