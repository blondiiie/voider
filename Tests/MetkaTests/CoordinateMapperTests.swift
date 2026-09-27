import Testing
import CoreGraphics
@testable import Metka

@Suite struct CoordinateMapperTests {
    // видео 1000x500 в слое 500x500: scale = 1, offsetX = -250, offsetY = 0
    private var mapper: CoordinateMapper {
        CoordinateMapper(videoSize: CGSize(width: 1000, height: 500),
                         layerSize: CGSize(width: 500, height: 500))
    }

    @Test func pointCorners() {
        let m = mapper
        #expect(m.point(CGPoint(x: 0, y: 0)) == CGPoint(x: -250, y: 0))
        #expect(m.point(CGPoint(x: 1, y: 1)) == CGPoint(x: 750, y: 500))
    }

    @Test func pointCenter() {
        let m = mapper
        #expect(m.point(CGPoint(x: 0.5, y: 0.5)) == CGPoint(x: 250, y: 250))
    }

    @Test func rect() {
        let m = mapper
        let r = m.rect(CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        #expect(r == CGRect(x: 0, y: 125, width: 500, height: 250))
    }

    @Test func distance() {
        let m = mapper
        #expect(abs(m.distance(CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)) - 1118.03) < 0.1) // hypot(1000, 500)
    }
}
