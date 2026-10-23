// isokit: people recipes. Each look renders 4 facings x 8 gait frames: `walker-[woman-]<facing>-<frame>` for
// residents and `carrier-<load>-<facing>-<frame>` for carriers, one look per good family.
import SceneKit

extension Recipes {
    static let gaitFrames = 8
    /// 32 x 32 pt: room for a hat, a shouldered load and the whole baked shadow, which falls to the right.
    static let walkerCell = SpriteCell(footprint: 1, heightPx: 32, widthPx: 32)
    /// The feet stand 5 pt above the cell's bottom edge, so a full stride, a load reaching back and the
    /// shadow under them stay in the cell, and 4 pt left of its centre (at 12 of 32 pt), so the shadow falling
    /// right fits too. The renderer anchors walkers there: (12/32, 5/32).
    static let walkerGround = ground(lift: 5, left: 4)

    /// The ground point that lands `lift` pt above a 1×1 cell's bottom centre and `left` pt left of it:
    /// up-screen is −x−z (8 pt per metre of each), left is −x+z (16 pt per metre of each).
    static func ground(lift: CGFloat, left: CGFloat) -> SCNVector3 {
        SCNVector3(4 - lift / 8 - left / 16, 0, 4 - lift / 8 + left / 16)
    }

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
        facingRecipes(stem, entry: "walker", cell: walkerCell, frames: gaitFrames, scale: figure.scale) { $0.figure(figure, phase: $1) }
    }

    /// One cycle in the four facings, as `<id>-<facing>-<frame>`: `build` draws frame phase 0…1 facing +x on
    /// the origin, and the recipe turns it to each facing with the feet on `walkerGround`.
    static func facingRecipes(
        _ id: String, entry: String, cell: SpriteCell, frames: Int, scale: CGFloat = 1, ground: SCNVector3 = walkerGround,
        _ build: @escaping (Builder, CGFloat) -> Void
    ) -> [Recipe] {
        WalkerFacing.allCases.map { facing in
            Recipe(
                id: "\(id)-\(facing.rawValue)",
                entry: entry,
                cell: cell,
                constructionFrames: 0,
                operationalFrames: frames,
                moving: MovingPart(name: "gait") { kit, frame in
                    kit.turned(facing, at: ground, scale: scale) { build($0, CGFloat(frame) / CGFloat(frames)) }
                },
                plot: nil,
                unit: true
            ) { _, _ in }
        }
    }
}

// MARK: animals

extension Recipes {
    /// Where each animal's feet stand in its cell, in pt from the cell's bottom-left corner. The renderer's
    /// `SpriteAtlas.AnimalAction.anchor` repeats these; the animal brief lists them and a test compares.
    struct Pen {
        let width: Int, height: Int, feetX: CGFloat, feetY: CGFloat

        var cell: SpriteCell {
            SpriteCell(footprint: 1, heightPx: height, widthPx: width)
        }

        var ground: SCNVector3 {
            Recipes.ground(lift: feetY, left: CGFloat(width) / 2 - feetX)
        }
    }

    static let sheepPen = Pen(width: 34, height: 26, feetX: 14, feetY: 7)
    static let cowPen = Pen(width: 52, height: 44, feetX: 21, feetY: 11)
    static let henPen = Pen(width: 18, height: 14, feetX: 8, feetY: 4)

    /// Sheep and cows walk (8 frames) and graze (4 frames); hens peck (4 frames).
    static let animals: [Recipe] = {
        func cycle(_ id: String, _ pen: Pen, _ frames: Int, _ build: @escaping (Builder, CGFloat) -> Void) -> [Recipe] {
            facingRecipes(id, entry: "animal", cell: pen.cell, frames: frames, ground: pen.ground, build)
        }
        return cycle("animal-sheep-walk", sheepPen, 8) { $0.beast(.sheep, .walk($1)) }
            + cycle("animal-sheep-graze", sheepPen, 4) { $0.beast(.sheep, .graze($1)) }
            + cycle("animal-cow-walk", cowPen, 8) { $0.beast(.cow, .walk($1)) }
            + cycle("animal-cow-graze", cowPen, 4) { $0.beast(.cow, .graze($1)) }
            + cycle("animal-hen", henPen, 4) { kit, phase in kit.hen(sin(phase * .pi)) }
    }()
}
