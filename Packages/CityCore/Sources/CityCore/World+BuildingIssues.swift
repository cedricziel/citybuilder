import Foundation

/// Why a building isn't doing its job. Spec: `warehouses-and-logistics`
/// / Buildings report why they are idle.
public enum BuildingIssue: Hashable, Sendable {
    case noRoad
    /// Its road doesn't reach a warehouse, port or town center.
    case noRouteToStorage
    case noTreesInReach
    case missingInputs([Good])
    case storageFull
}

public extension World {
    /// The first issue of each operational player house and producer, in
    /// the order a player has to fix them. A read-only query: it never
    /// touches simulation state.
    func buildingIssues() -> [EntityID: BuildingIssue] {
        let components = roadComponents()
        let storageComponents = Set(goodsBuffers(of: .player).compactMap { buffer -> Int? in
            guard buffer.state == .operational else { return nil }
            let footprint = BuildingCatalog.spec(for: buffer.kind).footprint
            return anyAdjacentRoad(anchor: buffer.anchor, footprint: footprint).flatMap { components[$0] }
        })
        var issues: [EntityID: BuildingIssue] = [:]
        for building in buildings.values where building.owner == .player && building.state == .operational {
            let recipe = Self.activeRecipe(of: building)
            guard building.kind == .house || recipe != nil else { continue }
            let footprint = BuildingCatalog.spec(for: building.kind).footprint
            guard let road = anyAdjacentRoad(anchor: building.anchor, footprint: footprint) else {
                issues[building.id] = .noRoad
                continue
            }
            let lacksForest = building.kind == .lumberjackHut
                && firstForestInCatchment(anchor: building.anchor, footprint: footprint) == nil
            if lacksForest {
                issues[building.id] = .noTreesInReach
                continue
            }
            guard let component = components[road], storageComponents.contains(component) else {
                issues[building.id] = .noRouteToStorage
                continue
            }
            if let recipe, let issue = productionIssue(of: building.id, recipe: recipe) {
                issues[building.id] = issue
            }
        }
        return issues
    }
}

extension World {
    private func productionIssue(of id: EntityID, recipe: ProductionRecipe) -> BuildingIssue? {
        let stockpile = stockpiles[id] ?? Stockpile(capacity: 16)
        let missing = recipe.inputs
            .filter { good, amount in stockpile.quantity(of: good) < amount }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }
        if !missing.isEmpty { return .missingInputs(missing) }
        if recipe.outputs.values.contains(where: { stockpile.totalStored + $0 > stockpile.capacity }) {
            return .storageFull
        }
        return nil
    }

    /// Connected-component label of every road tile.
    private func roadComponents() -> [TileCoordinate: Int] {
        var labels: [TileCoordinate: Int] = [:]
        var next = 0
        for start in roadGraph.roadTiles where labels[start] == nil {
            var stack = [start]
            labels[start] = next
            while let tile = stack.popLast() {
                for neighbor in roadGraph.adjacency[tile] ?? [] where labels[neighbor] == nil {
                    labels[neighbor] = next
                    stack.append(neighbor)
                }
            }
            next += 1
        }
        return labels
    }
}
