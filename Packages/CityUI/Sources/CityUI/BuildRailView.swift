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
                label: "Road",
                art: .building(.road),
                hotkey: BuildRailModel.roadHotkey,
                isOn: session.selectedTool == .place(.road)
            ) { arm(.place(.road)) }
            item(
                label: "Demolish",
                art: .symbol("xmark", .red),
                hotkey: BuildRailModel.demolishHotkey,
                isOn: session.selectedTool == .demolish
            ) { arm(.demolish) }
        }
        .padding(4)
        .frame(width: isVertical ? layout.railWidth : nil)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
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
            .frame(width: isVertical ? nil : (layout.isPhone ? 64 : 76), height: showsLabel ? 58 : 44)
            .overlay(alignment: .topTrailing) {
                if !layout.isTouch {
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
        .keyboardShortcut(KeyEquivalent(hotkey), modifiers: [])
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private func artView(_ art: Art) -> some View {
        switch art {
        case let .building(kind):
            BuildingIconLoader.image(for: kind)
                .resizable()
                .interpolation(GoodIconLoader.pixelArtInterpolation)
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

    var body: some View {
        if let category = rail.openDrawer {
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
                    .accessibilityLabel("Close")
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
                .frame(maxHeight: 280)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .fixedSize(horizontal: true, vertical: false)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
        }
    }

    private func tile(_ kind: BuildingKind) -> some View {
        let locked = session.isLocked(kind)
        let isArmed = session.selectedTool == .place(kind)
        let name = BuildTool.place(kind).displayName
        return Button {
            rail.arm(kind, in: session)
        } label: {
            VStack(spacing: 2) {
                BuildingIconLoader.image(for: kind)
                    .resizable()
                    .interpolation(GoodIconLoader.pixelArtInterpolation)
                    .scaledToFit()
                    .frame(height: 46, alignment: .bottom)
                HStack(spacing: 3) {
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                    }
                    Text(name).lineLimit(1).minimumScaleFactor(0.7)
                }
                .font(.system(size: 11, weight: .semibold))
                Text("$\(BuildingCatalog.spec(for: kind).cost)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
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
        .accessibilityLabel(locked ? "\(name), locked" : name)
        .accessibilityValue("$\(BuildingCatalog.spec(for: kind).cost)")
    }
}
