import CityCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The running device's idiom, for `HUDLayout`.
@MainActor
enum HUDMetrics {
    static var idiom: HUDIdiom {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
        #elseif os(tvOS)
        .tv
        #else
        .mac
        #endif
    }

    static func layout(for size: CGSize) -> HUDLayout {
        HUDLayout.make(size: size, idiom: idiom)
    }

    static let cornerRadius: CGFloat = 12
    /// The handoff's `fill` token: rgba(120,120,128,.2) light, .36 dark.
    static let fill = Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.28)
}

extension View {
    func settingsSheet(isPresented: Binding<Bool>, content: (() -> AnyView)?) -> some View {
        sheet(isPresented: isPresented) {
            if let content {
                content().hudSheetDetents()
            }
        }
    }

    /// Phone sheets open at 62% height. Spec: the HUD handoff, Sheets.
    /// Mac sheets size to their content, and a `List` has none, so they
    /// get a floor. Apple TV sheets get the TV width.
    func hudSheetDetents() -> some View {
        #if os(iOS)
        presentationDetents(HUDMetrics.idiom == .phone ? [.fraction(0.62), .large] : [.large])
        #elseif os(tvOS)
        tvSheetWidth()
        #else
        frame(minWidth: 420, idealWidth: 480, minHeight: 360, idealHeight: 520)
        #endif
    }
}

/// Date, money, population, island and speed in one capsule. Spec:
/// `platform-shells` / Status pill and stocks tray.
struct StatusPillView: View {
    let hud: HUDViewModel
    let session: GameSession
    let layout: HUDLayout
    let onTogglePause: () -> Void
    private let labels = LayoutDecisions.decisions(for: .compact).labels

    var body: some View {
        HStack(spacing: layout.isPhone ? 12 : 18) {
            if layout.showsDate, !hud.dateText.isEmpty {
                Label {
                    Text(hud.dateText).font(.system(size: 12, weight: .semibold))
                } icon: {
                    Image(systemName: hud.timeOfDaySymbol).font(.system(size: 14))
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel(GameText.string("a11y.date", hud.dateText))
            }
            stat(GameText.string("hud.money"), Text(hud.formattedMoney).monospaced())
            stat(GameText.string("hud.population"), Text(verbatim: "\(hud.population)").monospaced())
            if let name = hud.currentIslandName {
                islandButton(name)
            }
            SpeedControlView(session: session, layout: layout, onTogglePause: onTogglePause)
        }
        .padding(.leading, 16)
        .padding([.trailing, .vertical], 3)
        .frame(height: layout.controlHeight)
        .background(.thinMaterial, in: Capsule())
    }

    private static func caption(_ text: String) -> some View {
        Text(text.uppercased(with: Language.current.locale))
            .font(.system(size: 10))
            .tracking(0.3)
            .foregroundStyle(.secondary)
    }

    private func stat(_ label: String, _ value: Text) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Self.caption(label)
            value.font(.system(size: 15, weight: .semibold))
        }
        .lineLimit(labels.statValueLineLimit)
        .minimumScaleFactor(labels.minimumScaleFactor)
        .accessibilityElement(children: .combine)
    }

    private func islandButton(_ name: String) -> some View {
        Button(action: hud.toggleStocksTray) {
            HStack(spacing: 6) {
                stat(GameText.string("hud.island"), Text(name))
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(hud.isStocksTrayOpen ? 180 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -8)
        .accessibilityLabel(GameText.string("a11y.islandStocks", name))
        .accessibilityValue(hud.isStocksTrayOpen ? GameText.string("a11y.shown") : GameText.string("a11y.hidden"))
    }
}

/// Pause plus 1×, 2× and 3×; a single cycling button on a phone. Choosing
/// a speed resumes. Spec: `platform-shells` / Game speed.
struct SpeedControlView: View {
    let session: GameSession
    let layout: HUDLayout
    let onTogglePause: () -> Void

    private var height: CGFloat {
        layout.controlHeight - 6
    }

    private var buttonSize: CGFloat {
        height - 6
    }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onTogglePause) {
                Image(systemName: pauseButtonSymbolName(isPaused: session.isPaused))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(session.isPaused ? Color.white : Color.primary)
                    .frame(minWidth: buttonSize, minHeight: buttonSize)
                    .background(session.isPaused ? Color.accentColor : Color.clear, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.isPaused ? GameText.string("pause.resume") : GameText.string("commands.pause"))
            .pauseHotkeys()
            if layout.usesSpeedCycleButton {
                segment(session.speed.label, isOn: false, action: session.stepSpeed)
                    .accessibilityLabel(GameText.string("a11y.speed", session.speed.label))
            } else {
                ForEach(GameSpeed.allCases, id: \.self) { speed in
                    segment(speed.label, isOn: !session.isPaused && session.speed == speed) {
                        session.choose(speed: speed)
                    }
                    .accessibilityLabel(GameText.string("a11y.speed", speed.label))
                    .accessibilityAddTraits(session.speed == speed ? .isSelected : [])
                }
            }
        }
        .padding(3)
        .frame(height: height)
        .background(.thinMaterial, in: Capsule())
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isOn ? .bold : .semibold, design: .monospaced))
                .foregroundStyle(isOn || layout.usesSpeedCycleButton ? Color.primary : Color.secondary)
                .padding(.horizontal, 8)
                .frame(minWidth: buttonSize, minHeight: buttonSize)
                .background(isOn ? HUDMetrics.fill : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// How many columns of good chips the stocks tray shows, and how wide it
/// is, so it fits beside the minimap. Spec: `platform-shells` / Minimap
/// layout.
enum StocksTrayLayout {
    static let columnWidth: CGFloat = 96
    static let spacing: CGFloat = 14
    static let padding: CGFloat = 14

    static func columns(fitting width: CGFloat, isPhone: Bool, chips: Int) -> Int {
        let fit = Int((width - padding * 2 + spacing) / (columnWidth + spacing))
        return max(1, min(isPhone ? 3 : 6, chips, fit))
    }

    static func width(columns: Int) -> CGFloat {
        CGFloat(columns) * columnWidth + CGFloat(max(columns - 1, 0)) * spacing + padding * 2
    }
}

/// The current island's stocks under the pill. Spec: `platform-shells` /
/// Status pill and stocks tray.
struct StocksTrayView: View {
    let hud: HUDViewModel
    let layout: HUDLayout
    /// The width the tray may take; it drops columns to fit.
    let maxWidth: CGFloat

    var body: some View {
        let chips = hud.stocksTray
        if !chips.isEmpty {
            let count = StocksTrayLayout.columns(fitting: maxWidth, isPhone: layout.isPhone, chips: chips.count)
            let columns = Array(
                repeating: GridItem(
                    .fixed(StocksTrayLayout.columnWidth), spacing: StocksTrayLayout.spacing, alignment: .leading
                ),
                count: count
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: GameText.string(
                    "hud.stocksHeader",
                    hud.currentIslandName ?? GameText.string("hud.island"),
                    GameText.string("count.good", chips.count)
                ).uppercased(with: Language.current.locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(chips, id: \.good) { chip in
                        let name = chip.good.displayName
                        HStack(spacing: 6) {
                            GoodChipView(good: chip.good, text: "\(chip.count)")
                            Text(name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String("\(name) \(chip.count)"))
                    }
                }
            }
            .padding(.horizontal, StocksTrayLayout.padding)
            .padding(.vertical, 10)
            .frame(width: StocksTrayLayout.width(columns: count), alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(GameText.string("a11y.islandStocksTitle"))
        }
    }
}

/// A good's icon and a count, such as wood 42 or planks 18/4.
struct GoodChipView: View {
    let good: Good
    let text: String
    var color: Color = .primary
    /// Hover text; the good's name when nil.
    var help: String?

    var body: some View {
        HStack(spacing: 4) {
            GoodIconLoader.image(for: good)
                .resizable()
                .interpolation(GoodIconLoader.interpolation)
                .frame(width: 16, height: 16)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .fixedSize()
        .help(help ?? good.displayName)
        .accessibilityElement(children: .combine)
    }
}
