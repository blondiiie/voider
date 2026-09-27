import Testing
@testable import Metka

@Suite struct ContentKindTests {
    @Test func mapping() {
        #expect(ContentKind.from(.thumbUp) == .video)
        #expect(ContentKind.from(.victory) == .photo)
        #expect(ContentKind.from(.openPalm) == .audio)
        #expect(ContentKind.from(nil) == .idle)
    }
}
