import CityCore

/// Where residents may stand on a town center's plaza, in footprint-local
/// coordinates from the back corner (`u` along +x, `v` along +y, 0…3).
/// Measured on the town center sprites. A figure wanders only within its
/// lane, and no straight walk inside a lane crosses a prop, so nobody
/// stands in the well or walks through a stall. Spec: `rendering-2_5d` /
/// Residents gather on the plaza.
struct PlazaLayout: Sendable {
    typealias Spot = (u: Double, v: Double)

    struct Prop: Sendable {
        let name: String
        let alongU: ClosedRange<Double>
        let alongV: ClosedRange<Double>

        func contains(_ spot: Spot) -> Bool {
            alongU.contains(spot.u) && alongV.contains(spot.v)
        }
    }

    let lanes: [[Spot]]
    /// What a figure must keep clear of; the tests check every spot and
    /// every walk inside a lane against these.
    let props: [Prop]

    /// The Northern European (IsoKit) town center: hall and tower at the
    /// back, a well and two stalls on the plaza in front.
    static let northernEuropean = PlazaLayout(
        lanes: [
            // Between the hall and the stalls.
            [(0.9, 1.5), (1.45, 1.5), (1.8, 1.5)],
            // Along the front edge, clear of the crate.
            [(0.4, 2.8), (0.9, 2.8), (1.4, 2.85), (2.2, 2.85), (2.7, 2.8)],
            // Right of the yellow stall, clear of the barrels.
            [(2.75, 1.95), (2.6, 2.35), (2.85, 2.55)]
        ],
        props: [
            Prop(name: "hall and tower", alongU: 0 ... 3, alongV: 0 ... 1.35),
            Prop(name: "well", alongU: 0.3 ... 0.8, alongV: 1.75 ... 2.3),
            Prop(name: "red stall", alongU: 1.1 ... 1.6, alongV: 1.7 ... 2.3),
            Prop(name: "yellow stall", alongU: 1.9 ... 2.45, alongV: 1.45 ... 1.95),
            Prop(name: "barrels", alongU: 2.55 ... 2.85, alongV: 1.35 ... 1.75),
            Prop(name: "crate", alongU: 1.75 ... 2.1, alongV: 2.45 ... 2.75)
        ]
    )

    /// The culture town centers fill their footprint with the building;
    /// only a paved rim along the two front edges stays open.
    static let rim = PlazaLayout(
        lanes: [
            [(0.4, 2.88), (1.0, 2.88), (1.6, 2.88), (2.2, 2.88), (2.75, 2.88)],
            [(2.88, 0.6), (2.88, 1.2), (2.88, 1.8), (2.88, 2.4)]
        ],
        props: [Prop(name: "building", alongU: 0 ... 2.75, alongV: 0 ... 2.75)]
    )

    static func layout(for culture: Culture) -> PlazaLayout {
        culture == .northernEuropean ? northernEuropean : rim
    }
}
