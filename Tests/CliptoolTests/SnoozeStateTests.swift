import Testing
import Foundation

@Suite("SnoozeState") struct SnoozeStateTests {
    @Test func activeIsActive() {
        let state = SnoozeState.active
        #expect(state.isActive == true)
        #expect(state.skippedCount == 0)
    }

    @Test func offIsNotActive() {
        #expect(SnoozeState.off.isActive == false)
    }

    @Test func snoozedIsNotActive() {
        let state = SnoozeState.snoozed(.minutes(5), skipped: 0)
        #expect(state.isActive == false)
    }

    @Test func snoozedTracksSkips() {
        var state = SnoozeState.snoozed(.minutes(5), skipped: 0)
        #expect(state.skippedCount == 0)
        state.recordSkip()
        #expect(state.skippedCount == 1)
        state.recordSkip()
        #expect(state.skippedCount == 2)
    }

    @Test func activeRecordSkipIsNoop() {
        var state = SnoozeState.active
        state.recordSkip()
        #expect(state.isActive == true)
        #expect(state.skippedCount == 0)
    }

    @Test func offRecordSkipIsNoop() {
        var state = SnoozeState.off
        state.recordSkip()
        #expect(state.skippedCount == 0)
    }

    @Test func snoozeOptionLabels() {
        #expect(SnoozeOption.minutes(5).label == "Pause for 5m")
        #expect(SnoozeOption.minutes(30).label == "Pause for 30m")
        #expect(SnoozeOption.off.label == "Turn off")
    }

    @Test func snoozeOptionIntervals() {
        #expect(SnoozeOption.minutes(5).interval == 300)
        #expect(SnoozeOption.minutes(0).interval == 0)
        #expect(SnoozeOption.off.interval == nil)
    }
}
