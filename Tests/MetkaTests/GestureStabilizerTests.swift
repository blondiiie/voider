import Testing
@testable import Metka

@Suite struct GestureStabilizerTests {
    @Test func activateAfterNFrames() {
        var s = GestureStabilizer(activateFrames: 3, releaseFrames: 2)
        #expect(s.feed(.victory) == nil)
        #expect(s.feed(.victory) == nil)
        #expect(s.feed(.victory) == .victory, "активация на 3-м кадре")
    }

    @Test func interruptedSequenceDoesNotActivate() {
        var s = GestureStabilizer(activateFrames: 3, releaseFrames: 2)
        _ = s.feed(.victory); _ = s.feed(.victory); _ = s.feed(nil)
        #expect(s.feed(.victory) == nil, "счётчик сброшен — нужно снова 3 кадра")
        #expect(s.feed(.victory) == nil)
        #expect(s.feed(.victory) == .victory)
    }

    @Test func switchGestureRequiresNewStreak() {
        var s = GestureStabilizer(activateFrames: 2, releaseFrames: 2)
        _ = s.feed(.victory); #expect(s.feed(.victory) == .victory)
        #expect(s.feed(.thumbUp) == .victory, "пока держится старый")
        _ = s.feed(.thumbUp)
        #expect(s.feed(.thumbUp) == .thumbUp, "новый набрал серию")
    }

    @Test func releaseAfterMFrames() {
        var s = GestureStabilizer(activateFrames: 2, releaseFrames: 2)
        _ = s.feed(.openPalm); _ = s.feed(.openPalm)
        #expect(s.feed(nil) == .openPalm, "1 кадр отсутствия — ещё держим")
        #expect(s.feed(nil) == nil, "2 кадра отсутствия — отпустили")
    }

    @Test func nilNeverActivates() {
        var s = GestureStabilizer(activateFrames: 2, releaseFrames: 2)
        #expect(s.feed(nil) == nil); #expect(s.feed(nil) == nil)
    }
}
