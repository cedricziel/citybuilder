import CityCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Sizes shared by the map-first HUD pieces.
@MainActor
enum HUDMetrics {
    static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    static var controlHeight: CGFloat {
        ToolStripText.isTouch ? 50 : 40
    }

    static var railWidth: CGFloat {
        isPhone ? 56 : 76
    }

    static let cornerRadius: CGFloat = 12
}

/// Date, money, population, island and speed in one capsule. Spec:
/// `platform-shells` / Status pill and stocks tray.
struct StatusPillView: View {
    let hud: HUDViewModel
    let session: GameSession
    let onTogglePause: () -> Void
    private let labels = LayoutDecisions.decisions(for: .compact).labels

    var body: some View {
        HStack(spacing: HUDMetrics.isPhone ? 12 : 18) {
            if !HUDMetrics.isPhone, !hud.dateText.isEmpty {
                Label(hud.dateText, systemImage: hud.timeOfDaySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityLabel("Date: \(hud.dateText)")
            }
            stat("Money", hud.formattedMoney)
            stat("Pop.", "\(hud.population)")
            if let name = hud.currentIslandName {
                islandButton(name)
            }
            SpeedControlView(session: session, onTogglePause: onTogglePause)
        }
        .padding(.leading, 16)
        .padding([.trailing, .vertical], 3)
        .frame(height: HUDMetrics.controlHeight)
        .background(.regularMaterial, in: Capsule())
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
        }
        .lineLimit(labels.statValueLineLimit)
        .minimumScaleFactor(labels.minimumScaleFactor)
        .accessibilityElement(children: .combine)
    }

    private func islandButton(_ name: String) -> some View {
        Button(action: hud.toggleStocksTray) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ISLAND")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(hud.isStocksTrayOpen ? 180 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -8)
        .accessibilityLabel("Island \(name), stocks")
        .accessibilityValue(hud.isStocksTrayOpen ? "Shown" : "Hidden")
    }
}

/// Pause plus 1×, 2× and 3×; a single cycling button on a phone. Spec:
/// `platform-shells` / Game speed.
struct SpeedControlView: View {
    let session: GameSession
    let onTogglePause: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onTogglePause) {
                Image(systemName: pauseButtonSymbolName(isPaused: session.isPaused))
                    .font(.system(size: 15, weight: .semibold))
                    .frame(minWidth: segmentHeight, minHeight: segmentHeight)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
            .keyboardShortcut(.escape, modifiers: [])
            .keyboardShortcut(".", modifiers: .command)
            if HUDMetrics.isPhone {
                segment(session.speed.label, isOn: false) { session.speed = session.speed.next }
                    .accessibilityLabel("Speed \(session.speed.label)")
            } else {
                ForEach(GameSpeed.allCases, id: \.self) { speed in
                    segment(speed.label, isOn: session.speed == speed) { session.speed = speed }
                        .accessibilityLabel("Speed \(speed.label)")
                }
            }
        }
        .padding(3)
        .frame(height: HUDMetrics.controlHeight - 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var segmentHeight: CGFloat {
        HUDMetrics.controlHeight - 12
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .frame(minWidth: segmentHeight, minHeight: segmentHeight)
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                .background(isOn ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The current island's stocks under the pill. Spec: `platform-shells` /
/// Status pill and stocks tray.
struct StocksTrayView: View {
    let hud: HUDViewModel

    var body: some View {
        let chips = hud.stocksTray
        if !chips.isEmpty {
            let columns = Array(
                repeating: GridItem(.flexible(minimum: 52), spacing: 14, alignment: .leading),
                count: min(HUDMetrics.isPhone ? 4 : 6, chips.count)
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("\(hud.currentIslandName ?? "Island") stocks · \(chips.count) goods".uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(chips, id: \.good) { chip in
                        GoodChipView(good: chip.good, text: "\(chip.count)")
                            .accessibilityLabel("\(chip.good.rawValue.capitalized) \(chip.count)")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .fixedSize()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Island stocks")
        }
    }
}

/// A good's icon and a count, such as wood 42 or planks 18/4.
struct GoodChipView: View {
    let good: Good
    let text: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 4) {
            GoodIconLoader.image(for: good)
                .resizable()
                .interpolation(GoodIconLoader.pixelArtInterpolation)
                .frame(width: 16, height: 16)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}
