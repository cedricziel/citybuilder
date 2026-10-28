import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/add-orders: Order board layout.

// MARK: - Layout

private struct SizeClass {
    let name: String
    let size: CGSize
    let idiom: HUDIdiom

    init(_ name: String, _ size: CGSize, _ idiom: HUDIdiom) {
        self.name = name
        self.size = size
        self.idiom = idiom
    }
}

private let sizes = [
    SizeClass("phone landscape", CGSize(width: 844, height: 390), .phone),
    SizeClass("phone portrait", CGSize(width: 390, height: 844), .phone),
    SizeClass("pad landscape", CGSize(width: 1180, height: 820), .pad),
    SizeClass("pad portrait", CGSize(width: 820, height: 1180), .pad),
    SizeClass("mac", CGSize(width: 1280, height: 800), .mac),
    SizeClass("slide over", CGSize(width: 320, height: 800), .pad),
    SizeClass("tv", CGSize(width: 1920, height: 1080), .tv),
    SizeClass("iPhone mini landscape", CGSize(width: 667, height: 375), .phone),
    SizeClass("short Mac window", CGSize(width: 1000, height: 420), .mac)
]

@Test("scenario: board stays clear of the minimap and the build rail")
func scenarioBoardStaysClearOfTheMinimapAndTheBuildRail() {
    for sizeClass in sizes {
        let (name, size, idiom) = (sizeClass.name, sizeClass.size, sizeClass.idiom)
        let layout = HUDLayout.make(size: size, idiom: idiom)
        let insets = EdgeInsets(top: idiom == .phone ? 0 : 20, leading: 0, bottom: idiom.isTouch ? 20 : 0, trailing: 0)
        let safe = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        for showsMinimap in [true, false] {
            for showsFirstSteps in [true, false] {
                guard let board = OrderBoardLayout.frame(
                    in: size, insets: insets, layout: layout, showsMinimap: showsMinimap && idiom != .tv,
                    showsFirstSteps: showsFirstSteps
                )
                else {
                    #expect(OrderBoardLayout.presentation(
                        in: size, insets: insets, layout: layout, showsMinimap: showsMinimap && idiom != .tv,
                        showsFirstSteps: showsFirstSteps
                    ) == .sheet, "\(name): no frame means the sheet")
                    continue
                }
                #expect(safe.contains(board), "\(name): inside the screen")
                #expect(board.width == OrderBoardLayout.width(for: layout.idiom), "\(name)")
                let top = InspectorCalloutLayout.topBarBottom(topInset: insets.top, layout: layout)
                #expect(board.minY >= top, "\(name): below the top bar")
                if showsMinimap, idiom != .tv {
                    let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
                    #expect(!board.intersects(minimap), "\(name): minimap")
                }
                let railWidth = layout.railInset + layout.margin
                #expect(board.minX >= railWidth, "\(name): build rail")
                if layout.placement == .bottomDock {
                    #expect(board.maxY <= size.height - insets.bottom - layout.margin - 74, "\(name): dock")
                } else {
                    #expect(
                        board.maxY <= size.height - insets.bottom - layout.margin - OrderBoardLayout.toolStripBand
                            || showsMinimap,
                        "\(name): tool strip"
                    )
                }
            }
        }
    }
}

@Test("scenario: minimap at the top right pushes the board down")
func scenarioMinimapAtTheTopRightPushesTheBoardDown() throws {
    let size = CGSize(width: 820, height: 1180)
    let layout = HUDLayout.make(size: size, idiom: .pad)
    #expect(layout.placement == .bottomDock)
    let insets = EdgeInsets()
    let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
    let board = try #require(OrderBoardLayout.frame(in: size, insets: insets, layout: layout, showsMinimap: true, showsFirstSteps: false))
    #expect(board.minY == minimap.maxY + MinimapLayout.gap)
    let noMap = try #require(OrderBoardLayout.frame(in: size, insets: insets, layout: layout, showsMinimap: false, showsFirstSteps: false))
    #expect(noMap.minY < board.minY)
}

@Test("scenario: opening the board collapses the first-steps card")
func scenarioOpeningTheBoardCollapsesTheFirstStepsCard() {
    let layout = HUDLayout.make(size: CGSize(width: 1280, height: 800), idiom: .mac)
    #expect(!layout.collapsesFirstSteps)
    let collapsed = layout.withFirstStepsCollapsed
    #expect(collapsed.collapsesFirstSteps)
    #expect(collapsed.placement == layout.placement && collapsed.idiom == layout.idiom)
}

@Test("scenario: inspector and board coexist in regular widths")
func scenarioInspectorAndBoardCoexistInRegularWidths() {
    let size = CGSize(width: 1180, height: 820)
    let layout = HUDLayout.make(size: size, idiom: .pad)
    let insets = EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
    #expect(!OrderBoardLayout.replacesInspector(layout: layout))
    let with = InspectorCalloutLayout.freeArea(
        size: size, insets: insets, layout: layout, showsMinimap: true, showsOrdersBoard: true
    )
    let without = InspectorCalloutLayout.freeArea(size: size, insets: insets, layout: layout, showsMinimap: true)
    let board = OrderBoardLayout.frame(in: size, insets: insets, layout: layout, showsMinimap: true, showsFirstSteps: false)
    #expect(with.maxX <= (board?.minX ?? 0) - MinimapLayout.gap)
    #expect(with.maxX < without.maxX)
    #expect(with.minX == without.minX)
}

@MainActor
@Test("scenario: one replaces the other in a compact width")
func scenarioOneReplacesTheOtherInACompactWidth() {
    let layout = HUDLayout.make(size: CGSize(width: 844, height: 390), idiom: .phone)
    #expect(OrderBoardLayout.replacesInspector(layout: layout))
    let session = boardSession([order(1)])
    session.ordersReplaceInspector = true
    session.toggleOrdersBoard()
    session.selectedTile = TileCoordinate(x: 3, y: 3)
    session.handleTap(at: TileCoordinate(x: 4, y: 4))
    #expect(!session.isOrdersPresented)
    #expect(session.selectedTile == TileCoordinate(x: 4, y: 4))
    session.toggleOrdersBoard()
    #expect(session.isOrdersPresented)
    #expect(session.selectedTile == nil)
    let regular = boardSession([order(1)])
    regular.selectedTile = TileCoordinate(x: 3, y: 3)
    regular.toggleOrdersBoard()
    #expect(regular.isOrdersPresented && regular.selectedTile == TileCoordinate(x: 3, y: 3))
}

@Test("scenario: board is a sheet on a phone in portrait")
func scenarioBoardIsASheetOnAPhoneInPortrait() {
    let portrait = HUDLayout.make(size: CGSize(width: 390, height: 844), idiom: .phone)
    #expect(OrderBoardLayout.presentation(for: portrait) == .sheet)
    #expect(OrderBoardLayout.frame(
        in: CGSize(width: 390, height: 844),
        insets: EdgeInsets(),
        layout: portrait,
        showsMinimap: false,
        showsFirstSteps: false
    ) == nil)
    let landscape = HUDLayout.make(size: CGSize(width: 844, height: 390), idiom: .phone)
    #expect(OrderBoardLayout.presentation(for: landscape) == .column)
    let tv = HUDLayout.make(size: CGSize(width: 1920, height: 1080), idiom: .tv)
    #expect(OrderBoardLayout.presentation(for: tv) == .column)
    #expect(OrderBoardLayout.width(for: .tv) == 520 && OrderBoardLayout.width(for: .phone) == 300)
    #expect(OrderBoardLayout.width(for: .pad) == 340 && OrderBoardLayout.width(for: .mac) == 340)
}

@Test func theColumnFitsWhereThereIsRoom() {
    for sizeClass in sizes {
        let (name, size, idiom) = (sizeClass.name, sizeClass.size, sizeClass.idiom)
        let layout = HUDLayout.make(size: size, idiom: idiom)
        let fits = OrderBoardLayout.frame(
            in: size, insets: EdgeInsets(), layout: layout, showsMinimap: idiom != .tv, showsFirstSteps: true
        ) != nil
        let shown = OrderBoardLayout.presentation(
            in: size, insets: EdgeInsets(), layout: layout, showsMinimap: idiom != .tv, showsFirstSteps: true
        )
        #expect(shown == (fits ? .column : .sheet), "\(name)")
        if size.height >= 700, OrderBoardLayout.presentation(for: layout) == .column {
            #expect(fits, "\(name): room for the column")
        }
    }
}

@Test func theTvCapsuleBandUsesTheFocusableHeight() {
    let size = CGSize(width: 1920, height: 1080)
    let layout = HUDLayout.make(size: size, idiom: .tv)
    let phoneLike = HUDLayout.make(size: size, idiom: .mac)
    let tv = InspectorCalloutLayout.freeArea(size: size, insets: EdgeInsets(), layout: layout, showsMinimap: false, showsFirstSteps: true)
    let mac = InspectorCalloutLayout.freeArea(
        size: size,
        insets: EdgeInsets(),
        layout: phoneLike,
        showsMinimap: false,
        showsFirstSteps: true
    )
    // Both expand the card (no capsule band); collapse each to compare the bands.
    let tvBand = InspectorCalloutLayout.freeArea(
        size: size, insets: EdgeInsets(), layout: layout, showsMinimap: false, showsFirstSteps: true, showsOrdersBoard: true
    )
    let macBand = InspectorCalloutLayout.freeArea(
        size: size, insets: EdgeInsets(), layout: phoneLike, showsMinimap: false, showsFirstSteps: true, showsOrdersBoard: true
    )
    #expect(tv.width > 0 && mac.width > 0)
    let top = InspectorCalloutLayout.topBarBottom(topInset: 0, layout: layout)
    #expect(tvBand.minY == top + layout.focusableHeight(FirstStepsCardView.capsuleHeight) + MinimapLayout.gap)
    #expect(macBand.minY == InspectorCalloutLayout.topBarBottom(topInset: 0, layout: phoneLike) + FirstStepsCardView
        .capsuleHeight + MinimapLayout.gap)
}
