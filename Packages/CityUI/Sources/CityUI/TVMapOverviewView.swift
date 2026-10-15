#if os(tvOS)
import CityCore
import QuartzCore
import SwiftUI

/// The Apple TV map overview: the minimap full screen with a legend, the
/// cursor the remote moves and the remote's hints. The remote input itself
/// goes through `RemoteInputMapper`. Spec: `platform-shells` / Apple TV map
/// overview. Design D7.
struct TVMapOverviewView: View {
    let session: GameSession

    var body: some View {
        if let overview = session.overview {
            GeometryReader { proxy in
                let width = min(proxy.size.width - 160, (proxy.size.height - 300) * 2)
                let mapSize = CGSize(width: width, height: width / 2)
                VStack(spacing: 28) {
                    header
                    ZStack(alignment: .topLeading) {
                        MinimapCanvas(session: session, worldViewSize: proxy.size)
                        cursor(at: session.minimap.projection(size: mapSize).point(
                            tileX: Double(overview.cursorTile.x), tileY: Double(overview.cursorTile.y)
                        ))
                    }
                    .frame(width: mapSize.width, height: mapSize.height)
                    hints
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 60)
            .background(Color(red: 0.06, green: 0.12, blue: 0.18))
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tv.overview")
            .accessibilityLabel("Map, cursor at \(overview.cursorTile.x), \(overview.cursorTile.y)")
        }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Text("Map").font(.title2.bold())
            Spacer()
            legendItem("You", MinimapPalette.player)
            ForEach(session.world.rivals, id: \.id) { rival in
                legendItem(rival.name, MinimapRGBA(hex: rival.colour.hex))
            }
        }
        .padding(.horizontal, 80)
        .foregroundStyle(.white)
    }

    private func legendItem(_ name: String, _ colour: MinimapRGBA) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(Color(colour)).frame(width: 18, height: 18)
            Text(name).font(.callout)
        }
    }

    private var hints: some View {
        HStack(spacing: 48) {
            Text("Swipe or click to move the cursor")
            Text("Select: go there")
            Text("Back: close")
            Text("Hold Play/Pause: close and zoom in")
        }
        .font(.callout)
        .foregroundStyle(.white.opacity(0.75))
    }

    private func cursor(at point: CGPoint) -> some View {
        Image(systemName: "scope")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 3)
            .position(point)
            .accessibilityHidden(true)
    }
}

/// The top bar's Map button: opens the overview and hands the remote to
/// the map, which routes it to the overview's cursor.
struct TVMapButton: View {
    let session: GameSession
    let remote: TVRemoteController?

    var body: some View {
        Button {
            session.openOverview()
            remote?.focusMoved(toMap: true, at: CACurrentMediaTime())
        } label: {
            Image(systemName: "map.fill")
                .imageScale(.large)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map")
        .accessibilityIdentifier("hud.mapOverview")
    }
}
#endif
