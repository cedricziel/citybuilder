import CityCore
import Foundation
import SpriteKit

/// The building a range ring is drawn for: the placement ghost or the
/// selected building.
struct SignatureRingSource: Hashable {
    let kind: BuildingKind
    let anchor: TileCoordinate
    /// Tick the affected buildings were found at.
    let tick: UInt64
    let affected: [EntityID]
}

/// Range rings drawn in code. Spec: `rendering-2_5d` / Signature range
/// rings.
extension IsoWorldScene {
    static let signatureRingNodeName = "signature-ring"
    static let signatureHighlightNodeName = "signature-highlight"

    static let ringColour = SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 0.8)

    func reconcileSignatureRings(with snapshot: WorldSnapshot) {
        let wanted = signatureRingSourceKindAndAnchor(in: snapshot)
        guard !isShowingRings(for: wanted, at: snapshot.tickCount) else { return }
        let source = wanted.map { kind, anchor in
            SignatureRingSource(
                kind: kind, anchor: anchor, tick: snapshot.tickCount,
                affected: SignatureLooks.affectedBuildings(kind: kind, anchor: anchor, in: snapshot)
            )
        }
        signatureRingSource = source
        signatureRingLayer.removeAllChildren()
        if signatureRingLayer.parent == nil {
            signatureRingLayer.zPosition = 999
            addChild(signatureRingLayer)
        }
        guard let source else { return }
        for ring in SignatureLooks.rings(for: source.kind, at: source.anchor) {
            let node = Self.diamond(around: ring.bounds, colour: Self.ringColour)
            node.name = Self.signatureRingNodeName
            node.lineWidth = 2
            node.fillColor = Self.ringColour.withAlphaComponent(0.06)
            node.userData = ["tiles": ring.tiles]
            signatureRingLayer.addChild(node)
        }
        for id in source.affected {
            guard let target = snapshot.buildings[id] else { continue }
            let node = Self.diamond(around: target.bounds, colour: SKColor(red: 0.55, green: 1, blue: 0.55, alpha: 0.9))
            node.name = Self.signatureHighlightNodeName
            node.lineWidth = 1.5
            signatureRingLayer.addChild(node)
        }
    }

    /// True when the drawn rings already match `wanted` at `tick`.
    private func isShowingRings(for wanted: (BuildingKind, TileCoordinate)?, at tick: UInt64) -> Bool {
        guard let wanted else { return signatureRingSource == nil && signatureRingLayer.parent != nil }
        guard let current = signatureRingSource else { return false }
        return current.kind == wanted.0 && current.anchor == wanted.1 && current.tick == tick
    }

    private func signatureRingSourceKindAndAnchor(in snapshot: WorldSnapshot) -> (BuildingKind, TileCoordinate)? {
        if let ghost = ghostProvider?() {
            return ghost.kind.signatureReaches.isEmpty ? nil : (ghost.kind, ghost.tile)
        }
        guard let tile = selectionProvider?(), let id = snapshot.occupiedTiles[tile],
              let building = snapshot.buildings[id], !building.kind.signatureReaches.isEmpty
        else { return nil }
        return (building.kind, building.anchor)
    }

    /// Outline of the tiles in `bounds`, as the iso diamond on screen.
    private static func diamond(around bounds: TileBoundingBox, colour: SKColor) -> SKShapeNode {
        let west = Double(bounds.minX) - 0.5
        let north = Double(bounds.minY) - 0.5
        let east = Double(bounds.maxX) + 0.5
        let south = Double(bounds.maxY) + 0.5
        let path = CGMutablePath()
        path.move(to: IsoMath.screenPoint(forTileFractionalX: west, fractionalY: north))
        path.addLine(to: IsoMath.screenPoint(forTileFractionalX: east, fractionalY: north))
        path.addLine(to: IsoMath.screenPoint(forTileFractionalX: east, fractionalY: south))
        path.addLine(to: IsoMath.screenPoint(forTileFractionalX: west, fractionalY: south))
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.strokeColor = colour
        node.fillColor = .clear
        return node
    }
}
