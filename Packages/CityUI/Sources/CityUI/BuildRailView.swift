import CityCore
import SwiftUI

/// Town, Gather and Craft, then Road and Demolish: a rail on the left edge
/// in landscape, a dock along the bottom in portrait. Spec:
/// `platform-shells` / Build categories, rail and drawers.
struct BuildRailView: View {
    let session: GameSession
    @Binding var rail: BuildRailModel
    let layout: HUDLayout

    private var isVertical: Bool {
        layout.placement == .leftRail
    }

    var body: some View {
        let stack = isVertical
            ? AnyLayout(VStackLayout(spacing: 2))
            : AnyLayout(HStackLayout(spacing: 2))
        stack {
            ForEach(BuildCategory.allCases, id: \.self) { category in
                item(
                    label: category.label,
                    art: .building(category.representative),
                    hotkey: category.hotkey,
                    isOn: rail.highlightedCategory(armed: session.selectedTool) == category
                        && session.selectedTool != .place(.road)
                ) { rail.toggle(category) }
            }
            separator
            item(
                label: GameText.string("build.road"),
                art: .building(.road),
                hotkey: BuildRailModel.roadHotkey,
                isOn: session.selectedTool == .place(.road)
            ) { arm(.place(.road)) }
            item(
                label: GameText.string("tool.demolish"),
                art: .symbol("xmark", .red),
                hotkey: BuildRailModel.demolishHotkey,
                isOn: session.selectedTool == .demolish
            ) { arm(.demolish) }
        }
        .padding(4)
        .disabled(session.isGameOver)
        .opacity(session.isGameOver ? 0.4 : 1)
        .frame(width: isVertical ? layout.railWidth : nil)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
        .hudChromeTypeSize()
    }

    private func arm(_ tool: BuildTool) {
        rail.close()
        session.selectTool(tool)
    }

    @ViewBuilder
    private var separator: some View {
        if isVertical {
            Divider().padding(.horizontal, 6).padding(.vertical, 4)
        } else {
            Divider().frame(height: 40).padding(.horizontal, 2)
        }
    }

    enum Art {
        case building(BuildingKind)
        case symbol(String, Color)
    }

    private func item(
        label: String,
        art: Art,
        hotkey: Character,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let showsLabel = !isVertical || layout.railShowsLabels
        return Button(action: action) {
            VStack(spacing: 2) {
                artView(art).frame(height: 30)
                if showsLabel {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: isVertical ? .infinity : nil)
            .frame(width: isVertical ? nil : (layout.isPhone ? 64 : 76), height: layout.focusableHeight(showsLabel ? 58 : 44))
            .overlay(alignment: .topTrailing) {
                if layout.showsHotkeys {
                    Text(String(hotkey).uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 3)
                        .padding(.trailing, 4)
                }
            }
            .background(highlight(isOn))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .hotkey(KeyEquivalent(hotkey))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private func artView(_ art: Art) -> some View {
        switch art {
        case let .building(kind):
            BuildingIconLoader.image(for: kind)
                .resizable()
                .interpolation(BuildingIconLoader.interpolation(for: kind))
                .scaledToFit()
        case let .symbol(name, color):
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func highlight(_ isOn: Bool) -> some View {
        if isOn {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5))
        }
    }
}

/// The open category's buildings with sprite, name, cost and lock.
struct BuildDrawerView: View {
    let session: GameSession
    @Binding var rail: BuildRailModel
    let layout: HUDLayout
    /// The height the drawer may take, header and padding included: the tiles scroll in what is left.
    var availableHeight: CGFloat = .infinity

    /// The header, its spacing and the card's padding around the scrolling tiles.
    private static let chromeHeight: CGFloat = 64
    private static let maxTilesHeight: CGFloat = 280
    private static let minTilesHeight: CGFloat = 96

    static func tilesHeight(availableHeight: CGFloat) -> CGFloat {
        max(minTilesHeight, min(maxTilesHeight, availableHeight - chromeHeight))
    }

    var body: some View {
        if let category = rail.openDrawer, !session.isGameOver {
            let kinds = BuildCategory.kinds(in: category, isHidden: session.isHidden)
            let tileWidth: CGFloat = layout.isPhone ? 78 : 92
            let columnCount = layout.drawerColumns
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(category.label).font(.headline)
                    Spacer()
                    Button { rail.close() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(GameText.string("common.close"))
                }
                .padding(.horizontal, 4)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: 6), count: columnCount),
                        spacing: 6
                    ) {
                        ForEach(kinds, id: \.self) { kind in
                            tile(kind)
                        }
                    }
                }
                .frame(maxHeight: Self.tilesHeight(availableHeight: availableHeight))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .fixedSize(horizontal: true, vertical: false)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
            .hudChromeTypeSize()
            .panelTransition(PanelMotion.drawerStyle(for: layout.placement))
        }
    }

    private func tile(_ kind: BuildingKind) -> some View {
        let locked = session.isLocked(kind)
        let isArmed = session.selectedTool == .place(kind)
        let name = BuildTool.place(kind).displayName
        let accessibility = Self.tileAccessibility(for: kind, in: session)
        return Button {
            rail.arm(kind, in: session)
        } label: {
            VStack(spacing: 2) {
                BuildingIconLoader.image(for: kind)
                    .resizable()
                    .interpolation(BuildingIconLoader.interpolation(for: kind))
                    .scaledToFit()
                    .frame(height: 46, alignment: .bottom)
                HStack(spacing: 3) {
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                    }
                    Text(name).lineLimit(1).minimumScaleFactor(0.7)
                }
                .font(.system(size: 11, weight: .semibold))
                // Two lines at most and a word never breaks: "Needs Cultivation" wraps at its space
                // and shrinks until the longer word fits the tile.
                Text(session.drawerCaption(for: kind))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(HUDMetrics.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if isArmed {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .opacity(locked ? 0.5 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(accessibility.label)
        .accessibilityValue(accessibility.value)
    }

    /// What VoiceOver reads for a drawer tile: its name, marked when
    /// locked, and the caption the tile shows. Spec: `platform-shells` /
    /// Locked palette entries.
    @MainActor
    static func tileAccessibility(for kind: BuildingKind, in session: GameSession) -> (label: String, value: String) {
        let name = BuildTool.place(kind).displayName
        return (session.isLocked(kind) ? "\(name), locked" : name, session.drawerCaption(for: kind))
    }
}
