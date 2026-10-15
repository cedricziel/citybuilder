// isokit: people recipes. Each look renders 4 facings x 8 gait frames: `walker-[woman-]<facing>-<frame>` for
// residents and `carrier-<load>-<facing>-<frame>` for carriers, one look per good family.
import SceneKit

extension Recipes {
    static let gaitFrames = 8
    /// 24 x 30 pt: room for a hat, a shouldered load and the shadow falling to the right.
    static let walkerCell = SpriteCell(footprint: 1, heightPx: 30, widthPx: 24)
    /// Feet 2 pt above the cell's bottom edge (0.25 m up-screen of the bottom vertex), so the shadow under them fits.
    static let walkerGround = SCNVector3(3.75, 0, 3.75)
    /// Storybook scale (design D1): 1.15x a 1.7 m adult, with a larger head and thicker limbs so they read at zoom 1.
    static let storybook = Figure(scale: 1.15, head: 1.25, limbs: 1.2)

    /// The people looks, by sprite stem; the worker is plain `walker` (`walker-se-0`).
    static let walkerLooks: [(stem: String, figure: Figure)] = {
        func look(_ change: (inout Figure) -> Void) -> Figure {
            var figure = storybook
            change(&figure)
            return figure
        }
        return [
            ("walker", storybook),
            ("walker-woman", look {
                $0.tunic = Cloth.woad
                $0.skirt = Cloth.woad
                $0.apron = Cloth.linen
                $0.headwear = .coif
                $0.load = .basket
            }),
            ("carrier-sack", look {
                $0.tunic = Cloth.weld
                $0.hose = Cloth.walnut
                $0.headwear = .straw
                $0.load = .sack
            }),
            ("carrier-crate", look {
                $0.tunic = Cloth.woad
                $0.hose = Cloth.walnut
                $0.load = .crate
            }),
            ("carrier-barrel", look {
                $0.tunic = Cloth.linen
                $0.hose = Cloth.walnut
                $0.headwear = .hood
                $0.load = .barrel
            }),
            ("carrier-logs", look {
                $0.tunic = Cloth.fustian
                $0.hose = Cloth.walnut
                $0.headwear = .straw
                $0.load = .logs
            })
        ]
    }()

    static let walkers: [Recipe] = walkerLooks.flatMap { stem, figure in
        WalkerFacing.allCases.map { facing in
            Recipe(
                id: "\(stem)-\(facing.rawValue)",
                entry: "walker",
                cell: walkerCell,
                constructionFrames: 0,
                operationalFrames: gaitFrames,
                moving: MovingPart(name: "gait") { kit, frame in
                    kit.figure(figure, facing: facing, phase: CGFloat(frame) / CGFloat(gaitFrames), at: walkerGround)
                },
                plot: nil,
                unit: true
            ) { _, _ in }
        }
    }
}
