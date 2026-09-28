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
    private let faceRequest = VNDetectFaceLandmarksRequest() // в macOS 26+ SDK класс переименован из VNDetectFaceLandmarks2DRequest
    private let handRequest = VNDetectHumanHandPoseRequest()

    init() {
        handRequest.maximumHandCount = 1
    }

    func process(_ pixelBuffer: CVPixelBuffer) -> FrameObservation {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([faceRequest, handRequest])
        let size = CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                          height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))

        return FrameObservation(face: largestFace(in: size), handPoints: handPoints(), videoSize: size)
    }

    private func largestFace(in imageSize: CGSize) -> FaceInfo? {
        guard let face = faceRequest.results?.max(by: { $0.boundingBox.area < $1.boundingBox.area }) else {
            return nil
        }
        func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let region else { return nil }
            let pts = region.pointsInImage(imageSize: imageSize)
            guard !pts.isEmpty else { return nil }
            let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(pts.count) / imageSize.width,
                           y: sum.y / CGFloat(pts.count) / imageSize.height)
        }
        if let le = centroid(face.landmarks?.leftEye),
           let re = centroid(face.landmarks?.rightEye),
           let nose = centroid(face.landmarks?.nose) {
            return FaceInfo(boundingBox: face.boundingBox, leftEye: le, rightEye: re, noseTip: nose)
        }
        // Ландмарок нет — синтезируем глаза/нос из прямоугольника лица.
        let c = face.boundingBox.center
        return FaceInfo(boundingBox: face.boundingBox,
                        leftEye:  CGPoint(x: c.x - face.boundingBox.width * 0.18, y: c.y + face.boundingBox.height * 0.10),
                        rightEye: CGPoint(x: c.x + face.boundingBox.width * 0.18, y: c.y + face.boundingBox.height * 0.10),
                        noseTip:  CGPoint(x: c.x, y: c.y - face.boundingBox.height * 0.05))
    }

    private func handPoints() -> [VNHumanHandPoseObservation.JointName: CGPoint]? {
        guard let hand = handRequest.results?.first,
              let points = try? hand.recognizedPoints(.all) else { return nil }
        var dict: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
        for (name, point) in points where point.confidence > 0.3 {
            dict[name] = point.location
        }
        return dict.isEmpty ? nil : dict
    }
}
