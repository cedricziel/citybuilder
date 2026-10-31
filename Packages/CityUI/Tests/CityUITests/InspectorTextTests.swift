import CityCore
import Testing
@testable import CityUI

/// Spec: `localization` / Player-visible text comes from the catalogs. The
/// callout picks its lines by each template's text before the first
/// placeholder, so those markers must work in every language.
struct InspectorTextTests {
    @Test("the kind line names the building, not its code name")
    func kindLineNamesTheBuilding() {
        let building = Building(id: EntityID(raw: 1), kind: .grainFarm, anchor: TileCoordinate(x: 1, y: 1), state: .operational)
        let lines = InspectorViewModel.basicLines(for: building, buildProgress: "", hasRoad: true)
        #expect(lines.contains("Kind: Grain Farm"))
    }

    @Test("English markers match the old line prefixes")
    func englishMarkers() {
        let markers = InspectorViewModel.markerKeys.map { InspectorViewModel.marker($0) }
        #expect(markers.contains("State: "))
        #expect(markers.contains("Burnt down in "))
        #expect(markers.contains("Covers "))
        #expect(markers.contains("Keeps "))
        #expect(markers.contains("Burning"))
    }

    @Test("markers are distinct and non-empty in every language", arguments: [Language.en, .de, .pseudo])
    func markersDistinct(language: Language) {
        // l10n-check can't see keys held in arrays, so this checks they exist.
        #expect(InspectorViewModel.markerKeys.allSatisfy { GameText.string($0, in: language) != $0 })
        let markers = InspectorViewModel.markerKeys.map { InspectorViewModel.marker($0, in: language) }
        #expect(!markers.contains(""))
        // A marker that starts another would pick the other's line.
        for (index, marker) in markers.enumerated() {
            for (other, longer) in markers.enumerated() where other != index {
                #expect(!longer.hasPrefix(marker), "\(marker) starts \(longer)")
            }
        }
    }

    @Test("a German line starts with its German marker")
    func germanLineHasMarker() {
        let line = GameText.string("inspector.fireWatch.covers", "3 Gebäude", 8, in: .de)
        #expect(line == "Schützt 3 Gebäude im Umkreis von 8 Feldern über Straßen")
        #expect(line.hasPrefix(InspectorViewModel.marker("inspector.fireWatch.covers", in: .de)))
    }

    @Test("houses and workshops count in German")
    func germanCounts() {
        #expect(GameText.string("count.house", 1, in: .de) == "1 Haus")
        #expect(GameText.string("count.house", 2, in: .de) == "2 Häuser")
        #expect(GameText.string("count.workshop", 2, in: .de) == "2 Werkstätten")
        #expect(GameText.string("count.roadTile", 1) == "1 road tile")
    }
}
