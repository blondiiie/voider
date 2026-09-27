import Testing
@testable import Metka

@Suite struct SmokeTests {
    @Test func testModuleLoads() {
        #expect(true)
    }
}
