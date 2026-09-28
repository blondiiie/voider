import Vision
import CoreVideo
import CoreGraphics

struct FaceInfo {
    let boundingBox: CGRect   // нормализованный прямоугольник лица (Vision, origin снизу-слева)
    let leftEye: CGPoint      // нормализованные центры глаз и носа
    let rightEye: CGPoint
    let noseTip: CGPoint
}

struct FrameObservation {
    let face: FaceInfo?
    let handPoints: [VNHumanHandPoseObservation.JointName: CGPoint]?
    let videoSize: CGSize
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    var area: CGFloat { width * height }
}

final class VisionProcessor {
    func process(_ pixelBuffer: CVPixelBuffer) -> FrameObservation {
        // Task 8 добавит сюда face/hand запросы; сейчас — размеры кадра.
        FrameObservation(
            face: nil,
            handPoints: nil,
            videoSize: CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                              height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        )
    }
}
