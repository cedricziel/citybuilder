import CityCore
import Testing
@testable import CityUI

/// `%lld` groups digits in both languages ("1,203", "1.203"), which suits
/// counts and money but not years or tile coordinates. Those go into the
/// catalog as text.
struct UngroupedNumberTests {
    @Test("years before Christ are never grouped")
    func yearsBeforeChrist() {
        #expect(ChapterText.year(-1499) == "1500 BC")
        #expect(GameText.string("date.yearBC", "1500", in: .de) == "1500 v. Chr.")
    }

    @Test("tile coordinates are never grouped")
    func tileCoordinates() {
        let anchor = TileCoordinate(x: 1203, y: 1024)
        let building = Building(id: EntityID(raw: 1), kind: .road, anchor: anchor, state: .operational)
        let lines = InspectorViewModel.basicLines(for: building, buildProgress: "", hasRoad: true)
        #expect(lines.contains("Anchor: (1203, 1024)"))
        for key in ["a11y.reticle", "inspector.anchor", "map.a11y.cursor", "routes.yourPort"] {
            for language in [Language.en, .de] {
                #expect(GameText.string(key, "1203", "1024", in: language).contains("1203, 1024"), "\(key) \(language)")
            }
        }
    }
}
