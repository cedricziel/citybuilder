import Foundation

/// What one caravan sold. Spec: `culture-signatures` / Caravans sell at
/// base price.
public struct CaravanSale: Hashable, Codable, Sendable {
    public let goods: [Good: Int]
    public let revenue: Int64

    public init(goods: [Good: Int], revenue: Int64) {
        self.goods = goods
        self.revenue = revenue
    }
}

/// The caravanserai's export good, export supply and caravans (design D7).
extension World {
    public static let caravanIntervalTicks: UInt64 = 100
    /// Export good on hand plus in flight that supply stops at.
    static let exportStockCap = 8
    /// Units of the export good the island's buffers keep for themselves.
    static let exportReserve = 10

    /// Units one caravan takes: 4, 8 when served.
    static func caravanCapacity(of caravanserai: Building) -> Int {
        caravanserai.isServed ? 8 : 4
    }

    /// Spec: `culture-signatures` / The caravanserai exports a chosen good.
    /// Every building is the player's until `add-rival-towns` lands; then
    /// this also checks the caravanserai is the player's.
    mutating func applySetExport(_ id: EntityID, good: Good?) {
        guard let building = buildings[id], building.kind == .caravanserai else { return }
        let luxury = building.kind.fuel?.good
        guard good.map({ $0 != luxury }) ?? true else { return }
        buildings[id]?.exportGood = good
    }

    /// Supply carriers bring the export good one unit at a time while the
    /// caravanserai has under 8 on hand or in flight and its island's
    /// goods buffers hold more than the reserve.
    mutating func spawnExportCarriers(tileToIsland: [TileCoordinate: IslandID], events: inout [WorldEvent]) {
        let exporters = buildings.values
            .filter { $0.kind == .caravanserai && $0.state == .operational && $0.exportGood != nil }
            .sorted { $0.id.raw < $1.id.raw }
        for exporter in exporters {
            guard let good = exporter.exportGood, var wanted = exportWanted(exporter.id, good: good),
                  let road = anyAdjacentRoad(anchor: exporter.anchor, footprint: BuildingCatalog.spec(for: exporter.kind).footprint)
            else { continue }
            var surplus = islandStock(of: good, around: exporter, tileToIsland: tileToIsland) - Self.exportReserve
            while wanted > 0, surplus > 0, let (bufferID, path) = nearestBuffer(holding: good, toRoad: road) {
                dispatchSupply(good, from: bufferID, to: exporter.id, along: path, events: &events)
                wanted -= 1
                surplus -= 1
            }
        }
    }

    /// Units of `good` supply may still bring to the caravanserai `id`
    /// now: limited by the stock cap, its free space and the carrier cap.
    private func exportWanted(_ id: EntityID, good: Good) -> Int? {
        guard let stock = stockpiles[id] else { return nil }
        let inFlight = supplyCarrierCount(to: id)
        let goodInFlight = supplyCarrierCount(to: id, good: good)
        return min(
            Self.exportStockCap - stock.quantity(of: good) - goodInFlight,
            stock.freeSpace - inFlight,
            CarrierConfig.perProducerCap - inFlight
        )
    }

    /// `good` held by operational goods buffers on `building`'s island.
    private func islandStock(of good: Good, around building: Building, tileToIsland: [TileCoordinate: IslandID]) -> Int {
        let island = islandFor(building: building, tileToIsland: tileToIsland)
        return goodsBuffers()
            .filter { $0.state == .operational && islandFor(building: $0, tileToIsland: tileToIsland) == island }
            .reduce(0) { $0 + (stockpiles[$1.id]?.quantity(of: good) ?? 0) }
    }

    /// On ticks whose count is a multiple of 100, after fuel burns, each
    /// operational caravanserai sells up to its capacity: the export good
    /// first, then other goods in catalog order, never its luxury.
    mutating func sendCaravans(events: inout [WorldEvent]) {
        guard tickCount.isMultiple(of: Self.caravanIntervalTicks) else { return }
        let caravanserais = buildings.values
            .filter { $0.kind == .caravanserai && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        for caravanserai in caravanserais {
            guard var stock = stockpiles[caravanserai.id] else { continue }
            let luxury = caravanserai.kind.fuel?.good
            let order = (caravanserai.exportGood.map { [$0] } ?? []) + Good.allCases.filter { $0 != caravanserai.exportGood }
            var room = Self.caravanCapacity(of: caravanserai)
            var sold: [Good: Int] = [:]
            for good in order where good != luxury && room > 0 {
                let taken = stock.withdraw(good, amount: room)
                if taken > 0 {
                    sold[good] = taken
                    room -= taken
                }
            }
            guard !sold.isEmpty else { continue }
            let revenue = sold.reduce(Int64(0)) { $0 + Int64($1.value) * $1.key.basePrice }
            stockpiles[caravanserai.id] = stock
            buildings[caravanserai.id]?.lastCaravan = CaravanSale(goods: sold, revenue: revenue)
            credit(revenue, toOwnerOf: caravanserai)
            events.append(.caravanSold(building: caravanserai.id, goods: sold, revenue: revenue))
        }
    }

    /// Owner seam for income outside the tax interval. Every building is
    /// the player's until `add-rival-towns` lands; then this credits the
    /// owner's purse.
    private mutating func credit(_ amount: Int64, toOwnerOf _: Building) {
        economy.credit(amount)
    }
}
