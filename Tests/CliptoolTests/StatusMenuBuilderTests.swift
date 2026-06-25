import Testing
import AppKit
import CJanet

@Suite("StatusMenuBuilder") struct StatusMenuBuilderTests {
    private func rule(_ name: String, _ trigger: TriggerMode) -> RegisteredRule {
        RegisteredRule(name: name, trigger: trigger, matcher: Janet(), transform: Janet())
    }

    private func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.title }
    }

    @Test func nothingToFormatWhenEmpty() {
        let menu = StatusMenuBuilder.build(
            always: [], manual: [], snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(menu).contains("Nothing to format"))
    }

    @Test func singleAlwaysRuleShownDirectly() {
        let menu = StatusMenuBuilder.build(
            always: [rule("Upper", .always)], manual: [],
            snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(menu).contains("Upper"))
        // No "pick one" header for a single auto rule.
        #expect(!titles(menu).contains { $0.contains("auto rules matched") })
    }

    @Test func multipleAlwaysRulesShowPicker() {
        let menu = StatusMenuBuilder.build(
            always: [rule("A", .always), rule("B", .always)], manual: [],
            snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(menu).contains("2 auto rules matched — pick one"))
        #expect(titles(menu).contains("A"))
        #expect(titles(menu).contains("B"))
    }

    @Test func multipleAlwaysRulesStillShowManualRules() {
        // Regression: when >1 always rules match, manual rules must still be
        // reachable (they used to be hidden entirely).
        let menu = StatusMenuBuilder.build(
            always: [rule("A", .always), rule("B", .always)],
            manual: [rule("M1", .manual), rule("M2", .manual)],
            snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        let t = titles(menu)
        #expect(t.contains("Manual"))
        #expect(t.contains("M1"))
        #expect(t.contains("M2"))
    }

    @Test func multipleAlwaysWithoutManualHidesManualHeader() {
        let menu = StatusMenuBuilder.build(
            always: [rule("A", .always), rule("B", .always)], manual: [],
            snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(!titles(menu).contains("Manual"))
    }

    @Test func singleAlwaysPlusManualShownTogether() {
        let menu = StatusMenuBuilder.build(
            always: [rule("A", .always)], manual: [rule("M", .manual)],
            snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        let t = titles(menu)
        #expect(t.contains("A"))
        #expect(t.contains("M"))
    }

    @Test func snoozedStateShowsSnoozedHeaderAndResume() {
        let menu = StatusMenuBuilder.build(
            always: [], manual: [], snoozeState: .snoozed(.minutes(5), skipped: 0),
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        let t = titles(menu)
        #expect(t.contains("Snoozed"))
        #expect(t.contains("Resume"))
    }

    @Test func snoozedStateWithSkipsShowsCount() {
        let menu = StatusMenuBuilder.build(
            always: [], manual: [],
            snoozeState: .snoozed(.minutes(5), skipped: 3),
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(menu).contains("Snoozed — 3 skipped"))
    }

    @Test func offStateShowsOffHeader() {
        let menu = StatusMenuBuilder.build(
            always: [], manual: [], snoozeState: .off,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(menu).contains("clipfmt is off"))
    }

    @Test func errorShownAtTop() {
        let menu = StatusMenuBuilder.build(
            always: [], manual: [], snoozeState: .active, error: "boom",
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(menu).first == "⚠ Config error: boom")
    }

    @Test func snoozeSubmenuOnlyWhenActive() {
        let active = StatusMenuBuilder.build(
            always: [], manual: [], snoozeState: .active,
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(titles(active).contains("Snooze"))

        let snoozed = StatusMenuBuilder.build(
            always: [], manual: [], snoozeState: .snoozed(.minutes(5), skipped: 0),
            onApply: { _ in }, onSnooze: { _ in }, onQuit: {})
        #expect(!titles(snoozed).contains("Snooze"))
        #expect(titles(snoozed).contains("Resume"))
    }
}
