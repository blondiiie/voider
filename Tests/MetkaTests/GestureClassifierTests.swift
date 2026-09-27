import Testing
import CoreGraphics
import Vision
@testable import Metka

@Suite struct GestureClassifierTests {
    // Координаты Vision: нормализованные 0..1, ось Y вверх, origin снизу-слева.

    private func openPalm() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        [
            .wrist:      CGPoint(x: 0.50, y: 0.10),
            .thumbCMC:   CGPoint(x: 0.42, y: 0.16),
            .thumbMP:    CGPoint(x: 0.36, y: 0.26),
            .thumbTip:   CGPoint(x: 0.31, y: 0.36),
            .indexMCP:   CGPoint(x: 0.43, y: 0.34),
            .indexPIP:   CGPoint(x: 0.41, y: 0.46),
            .indexDIP:   CGPoint(x: 0.40, y: 0.55),
            .indexTip:   CGPoint(x: 0.39, y: 0.62),
            .middleMCP:  CGPoint(x: 0.49, y: 0.35),
            .middlePIP:  CGPoint(x: 0.49, y: 0.49),
            .middleDIP:  CGPoint(x: 0.49, y: 0.59),
            .middleTip:  CGPoint(x: 0.49, y: 0.67),
            .ringMCP:    CGPoint(x: 0.55, y: 0.33),
            .ringPIP:    CGPoint(x: 0.56, y: 0.46),
            .ringDIP:    CGPoint(x: 0.57, y: 0.55),
            .ringTip:    CGPoint(x: 0.58, y: 0.62),
            .littleMCP:  CGPoint(x: 0.60, y: 0.29),
            .littlePIP:  CGPoint(x: 0.62, y: 0.38),
            .littleDIP:  CGPoint(x: 0.63, y: 0.44),
            .littleTip:  CGPoint(x: 0.64, y: 0.49),
        ]
    }

    private func victory() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        var p = openPalm()
        // сгибаем безымянный и мизинец
        p[.ringTip]   = CGPoint(x: 0.52, y: 0.36)
        p[.littleTip] = CGPoint(x: 0.56, y: 0.30)
        return p
    }

    private func thumbUp() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        [
            .wrist:      CGPoint(x: 0.50, y: 0.10),
            .thumbCMC:   CGPoint(x: 0.42, y: 0.16),
            .thumbMP:    CGPoint(x: 0.44, y: 0.34),
            .thumbTip:   CGPoint(x: 0.46, y: 0.62),
            .indexMCP:   CGPoint(x: 0.53, y: 0.22),
            .indexPIP:   CGPoint(x: 0.55, y: 0.32),
            .indexDIP:   CGPoint(x: 0.55, y: 0.28),
            .indexTip:   CGPoint(x: 0.55, y: 0.24),
            .middleMCP:  CGPoint(x: 0.50, y: 0.20),
            .middlePIP:  CGPoint(x: 0.50, y: 0.34),
            .middleDIP:  CGPoint(x: 0.50, y: 0.30),
            .middleTip:  CGPoint(x: 0.50, y: 0.26),
            .ringMCP:    CGPoint(x: 0.47, y: 0.19),
            .ringPIP:    CGPoint(x: 0.45, y: 0.32),
            .ringDIP:    CGPoint(x: 0.45, y: 0.28),
            .ringTip:    CGPoint(x: 0.45, y: 0.24),
            .littleMCP:  CGPoint(x: 0.44, y: 0.17),
            .littlePIP:  CGPoint(x: 0.41, y: 0.29),
            .littleDIP:  CGPoint(x: 0.41, y: 0.25),
            .littleTip:  CGPoint(x: 0.41, y: 0.22),
        ]
    }

    private func fist() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        var p = thumbUp()
        p[.thumbTip] = CGPoint(x: 0.44, y: 0.30) // большой палец прижат
        return p
    }

    @Test func classifiesOpenPalm() {
        #expect(GestureClassifier.classify(openPalm()) == .openPalm)
    }

    @Test func classifiesVictory() {
        #expect(GestureClassifier.classify(victory()) == .victory)
    }

    @Test func classifiesThumbUp() {
        #expect(GestureClassifier.classify(thumbUp()) == .thumbUp)
    }

    @Test func fistIsNil() {
        #expect(GestureClassifier.classify(fist()) == nil)
    }

    @Test func emptyIsNil() {
        #expect(GestureClassifier.classify([:]) == nil)
    }

    @Test func distance() {
        #expect(abs(GestureClassifier.distance(CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)) - 5) < 0.0001)
    }
}
