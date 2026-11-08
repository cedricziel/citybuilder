import CityCore
import SwiftUI

/// The callout's header: the building's picture, its name in serif and a
/// house's tier as a tag. Spec: `platform-shells` / Callout shows goods as icons.
struct CalloutTitle: View {
    let kind: BuildingKind?
    let title: String
    let tier: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let kind {
                BuildingIconLoader.image(for: kind)
                    .resizable()
                    .interpolation(BuildingIconLoader.interpolation(for: kind))
                    .scaledToFit()
                    .frame(width: 52, height: 42, alignment: .bottom)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Parchment.title()).fixedSize(horizontal: false, vertical: true)
                if let tier {
                    Text(tier.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .foregroundStyle(Parchment.paper)
                        .background(Parchment.ink, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .accessibilityLabel(tier)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// A good's icon at a size.
struct GoodIcon: View {
    let good: Good
    var size: CGFloat = 18

    var body: some View {
        GoodIconLoader.image(for: good)
            .resizable()
            .interpolation(GoodIconLoader.interpolation)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A house's needs, one chip each, the ones it lacks highlighted.
struct NeedChipsView: View {
    let chips: [NeedChip]

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(chips, id: \.good) { chip in
                HStack(spacing: 4) {
                    GoodIcon(good: chip.good)
                    Text(chip.name)
                    if !chip.isMet {
                        Text(verbatim: "· \(GameText.string("inspector.need.shortTag"))")
                    }
                }
                .font(.caption.weight(chip.isMet ? .regular : .semibold))
                .foregroundStyle(chip.isMet ? Parchment.ink : Parchment.onShort)
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .padding(.vertical, 2)
                .background(chip.isMet ? Parchment.sunk : Parchment.short, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chip.spokenLabel)
            }
        }
    }
}

/// What a producer takes in, an arrow, and what it makes, per cycle.
struct RecipeRow: View {
    let recipe: RecipeSummary

    var body: some View {
        HStack(spacing: 6) {
            amounts(recipe.inputs)
            if !recipe.inputs.isEmpty {
                Image(systemName: "arrow.right").font(.caption.weight(.semibold)).foregroundStyle(Parchment.edge)
            }
            amounts(recipe.outputs)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.spokenLabel)
    }

    private func amounts(_ goods: [GoodAmount]) -> some View {
        HStack(spacing: 4) {
            ForEach(goods, id: \.good) { item in
                HStack(spacing: 3) {
                    GoodIcon(good: item.good)
                    Text(verbatim: "\(item.amount)").font(.caption.monospacedDigit())
                }
                .padding(.leading, 4)
                .padding(.trailing, 7)
                .padding(.vertical, 2)
                .background(Parchment.sunk, in: Capsule())
            }
        }
    }
}

/// What stops the building, on a dark red band.
struct ProblemAlert: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Parchment.onAlert)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Parchment.alert, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Lays chips out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
