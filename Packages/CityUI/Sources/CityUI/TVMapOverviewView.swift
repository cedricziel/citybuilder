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
                let width = MapOverview.mapWidth(in: proxy.size)
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
            .padding(.vertical, MapOverview.verticalPadding)
            .background(Color(red: 0.06, green: 0.12, blue: 0.18))
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tv.overview")
            .accessibilityLabel(GameText.string("map.a11y.cursor", "\(overview.cursorTile.x)", "\(overview.cursorTile.y)"))
        }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Text(l10n: "map.title").font(.title2.bold())
            Spacer()
            TVMapLegend(rivals: session.minimap.rivals)
        }
        .padding(.horizontal, 80)
        .foregroundStyle(.white)
    }

    private var hints: some View {
        HStack(spacing: 48) {
            Text(l10n: "map.hintMove")
            Text(l10n: "map.hintSelect")
            Text(l10n: "map.hintBack")
            Text(l10n: "map.hintPlayPause")
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

/// Who owns which colour: the player, then each rival. Takes the rivals
/// as a value so the overview does not redraw with every tick.
private struct TVMapLegend: View {
    let rivals: [MinimapRival]

    var body: some View {
        HStack(spacing: 24) {
            item(GameText.string("stats.you"), Color(MinimapPalette.player))
            ForEach(rivals, id: \.name) { rival in
                item(rival.name, Color(hex: rival.colourHex))
            }
        }
    }

    private func item(_ name: String, _ colour: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(colour).frame(width: 18, height: 18)
            Text(name).font(.callout)
        }
    }
}

/// The top bar's Map button: opens the overview and hands the remote to
/// the map, which routes it to the overview's cursor.
struct TVMapButton: View {
    let session: GameSession
    let remote: TVRemoteController?

    var body: some View {
        Button {
            if let remote {
                remote.openOverview(at: CACurrentMediaTime())
            } else {
                session.openOverview()
            }
        } label: {
            Image(systemName: "map.fill")
                .imageScale(.large)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GameText.string("map.title"))
        .accessibilityIdentifier("hud.mapOverview")
    }
}
#endif
