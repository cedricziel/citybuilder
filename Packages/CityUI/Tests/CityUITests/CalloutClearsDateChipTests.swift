import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityUI

// The phone's date chip and the event chip sit under the status pill, in
// the HUD's left column, and draw over the inspector callout. A tall
// callout, such as the expanded town center, must start below them.

// iPhone 17 in portrait: 402 x 874 points.
private let phoneSize = CGSize(width: 402, height: 874)
private let phoneInsets = EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)

@Test("the left column's chips: the date chip, then the event chip 8 points under it")
func theLeftColumnsChipsStackTheDateChipThenTheEventChip() {
    let phone = HUDLayout.make(size: phoneSize, idiom: .phone)
    let date = DateChipLayout.columnChipsHeight(showsDate: true, showsEvent: false, layout: phone)
    #expect(date == 4 + DateChipLayout.height)
    let both = DateChipLayout.columnChipsHeight(showsDate: true, showsEvent: true, layout: phone)
    #expect(both == date + 8 + EventChipLayout.height(layout: phone))
    #expect(DateChipLayout.columnChipsHeight(showsDate: false, showsEvent: false, layout: phone) == 0)
}

@Test("iPhone: an expanded callout near the top stays clear of the date chip")
func iPhoneAnExpandedCalloutNearTheTopStaysClearOfTheDateChip() {
    let phone = HUDLayout.make(size: phoneSize, idiom: .phone)
    let chips = DateChipLayout.columnChipsHeight(showsDate: true, showsEvent: false, layout: phone)
    let bounds = InspectorCalloutLayout.freeArea(
        size: phoneSize, insets: phoneInsets, layout: phone, showsMinimap: false, leadingChipsHeight: chips
    )
    let barBottom = InspectorCalloutLayout.topBarBottom(topInset: phoneInsets.top, layout: phone)
    let dateChip = CGRect(
        x: phoneInsets.leading + phone.margin + phone.railInset, y: barBottom + 4,
        width: DateChipLayout.width, height: DateChipLayout.height
    )
    // The playtest's shot 09: the market callout, expanded, over a town
    // center under the top bar.
    let calloutSize = CGSize(width: InspectorCalloutLayout.width(for: .phone), height: 400)
    let placed = InspectorCalloutLayout.place(
        anchor: CGPoint(x: 230, y: 330), buildingHalfSize: CGSize(width: 48, height: 40),
        calloutSize: calloutSize, bounds: bounds, placement: phone.placement
    )
    #expect(!CGRect(origin: placed.origin, size: calloutSize).intersects(dateChip))
}

@Test("the chips lower the free area's top and change nothing else")
func theChipsLowerTheFreeAreasTopAndChangeNothingElse() {
    let phone = HUDLayout.make(size: phoneSize, idiom: .phone)
    let without = InspectorCalloutLayout.freeArea(size: phoneSize, insets: phoneInsets, layout: phone, showsMinimap: false)
    let with = InspectorCalloutLayout.freeArea(
        size: phoneSize, insets: phoneInsets, layout: phone, showsMinimap: false, leadingChipsHeight: 30
    )
    #expect(with.minY == without.minY + 30 + MinimapLayout.gap)
    #expect(with.maxY == without.maxY)
    #expect(with.minX == without.minX && with.maxX == without.maxX)
}

@Test("a lower band, such as the minimap's, still wins over the chips")
func aLowerBandStillWinsOverTheChips() {
    let phone = HUDLayout.make(size: phoneSize, idiom: .phone)
    let minimap = InspectorCalloutLayout.freeArea(size: phoneSize, insets: phoneInsets, layout: phone, showsMinimap: true)
    let both = InspectorCalloutLayout.freeArea(
        size: phoneSize, insets: phoneInsets, layout: phone, showsMinimap: true, leadingChipsHeight: 30
    )
    #expect(both.minY == max(minimap.minY, InspectorCalloutLayout.topBarBottom(topInset: phoneInsets.top, layout: phone) + 30 + 8))
}
