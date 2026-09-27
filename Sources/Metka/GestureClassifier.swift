import CoreGraphics
import Vision

enum HandGesture: String {
    case thumbUp = "👍"
    case victory = "✌️"
    case openPalm = "🖐"
}

enum GestureClassifier {
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Палец выпрямлен, если его кончик дальше от запястья, чем средний сустав (инвариант к повороту кисти).
    static func isFingerExtended(tip: CGPoint, pip: CGPoint, wrist: CGPoint) -> Bool {
        distance(tip, wrist) > distance(pip, wrist) * 1.15
    }

    /// Большой выпрямлен, если кончик заметно дальше от основания указательного, чем его средний сустав.
    static func isThumbExtended(tip: CGPoint, mp: CGPoint, indexMCP: CGPoint) -> Bool {
        distance(tip, indexMCP) > distance(mp, indexMCP) * 1.2
    }

    static func classify(_ p: [VNHumanHandPoseObservation.JointName: CGPoint]) -> HandGesture? {
        guard let wrist = p[.wrist],
              let iMCP = p[.indexMCP], let iTIP = p[.indexTip], let iPIP = p[.indexPIP],
              let mTIP = p[.middleTip], let mPIP = p[.middlePIP],
              let rTIP = p[.ringTip], let rPIP = p[.ringPIP],
              let lTIP = p[.littleTip], let lPIP = p[.littlePIP],
              let tTIP = p[.thumbTip], let tMP = p[.thumbMP] else { return nil }

        let index  = isFingerExtended(tip: iTIP, pip: iPIP, wrist: wrist)
        let middle = isFingerExtended(tip: mTIP, pip: mPIP, wrist: wrist)
        let ring   = isFingerExtended(tip: rTIP, pip: rPIP, wrist: wrist)
        let little = isFingerExtended(tip: lTIP, pip: lPIP, wrist: wrist)
        let thumb  = isThumbExtended(tip: tTIP, mp: tMP, indexMCP: iMCP)

        if index && middle && ring && little { return .openPalm }
        if index && middle && !ring && !little { return .victory }
        if thumb && !index && !middle && !ring && !little && tTIP.y > wrist.y + 0.15 {
            return .thumbUp
        }
        return nil
    }
}
