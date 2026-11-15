import Foundation
import Testing
@testable import CityCore

// openspec/changes/add-campaigns (campaigns / Every chapter passes its
// sweep): on Normal, the bot each chapter's sweep names wins The Long
// Chronicle's chapters on the chapter's own seed before the deadline, with
// at least half a year to spare. The full ten-seed sweep on every
// difficulty (task 4.2) is still to come; the margins measured on the
// chapter seed are in design D10.

private let minimumMargin = Int(CalendarState.ticksPerYear) / 2

@Test(
    "a guided bot wins each Long Chronicle chapter on Normal before its deadline",
    arguments: ["first-fires", "bread-and-stone", "ore-and-anvil", "across-the-water", "the-guild-charter"]
)
func aGuidedBotWinsEachChronicleChapter(id: String) throws {
    let chapter = try #require(CampaignCatalog.chapter(id))
    let run = World.chapterBotRun(chapter, difficulty: .normal)
    let progress = run.world.goals.map { state in
        let value = run.world.progress(toward: state.goal)
        return "\(state.goal)=\(value.current)/\(value.target)\(state.isBonus ? " (bonus)" : "")"
    }
    print(
        "CHAPTER_RUN \(id) won=\(run.wonTick.map(String.init) ?? "-") margin=\(run.marginTicks.map(String.init) ?? "-") "
            + "loss=\(run.loss.map { "\($0)" } ?? "-") \(progress.joined(separator: ", "))"
    )
    #expect(run.wonTick != nil, "\(id): \(progress)")
    #expect((run.marginTicks ?? 0) >= minimumMargin, "\(id): margin \(run.marginTicks ?? 0) ticks")
}
