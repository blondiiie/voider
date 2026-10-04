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
    private var lastFaceCenter: CGPoint? // «липкое» отслеживание: маска не прыгает между лицами

    init() {
        handRequest.maximumHandCount = 1
    }

    func process(_ pixelBuffer: CVPixelBuffer) -> FrameObservation {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([faceRequest, handRequest])
        let size = CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                          height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))

        return FrameObservation(face: primaryFace(in: size), handPoints: handPoints(), videoSize: size)
    }

    // При нескольких лицах: держимся ближайшего к прошлому кадру (маска не
    // скачет), а когда прошлых данных нет — берём самое крупное лицо.
    private func primaryFace(in imageSize: CGSize) -> FaceInfo? {
        guard let results = faceRequest.results, !results.isEmpty else {
            lastFaceCenter = nil
            return nil
        }
        let chosen: VNFaceObservation
        if let last = lastFaceCenter {
            chosen = results.min(by: { a, b in
                let da = a.boundingBox.center, db = b.boundingBox.center
                return hypot(da.x - last.x, da.y - last.y) < hypot(db.x - last.x, db.y - last.y)
            })!
        } else {
            chosen = results.max(by: { $0.boundingBox.area < $1.boundingBox.area })!
        }
        lastFaceCenter = chosen.boundingBox.center
        return faceInfo(from: chosen, in: imageSize)
    }

    private func faceInfo(from face: VNFaceObservation, in imageSize: CGSize) -> FaceInfo? {
        func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let region else { return nil }
            let pts = region.pointsInImage(imageSize: imageSize)
            guard !pts.isEmpty else { return nil }
            let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(pts.count) / imageSize.width,
                           y: sum.y / CGFloat(pts.count) / imageSize.height)
        }
        // Превью фронтальной камеры зеркалит изображение (selfie-вид), а
        // координаты Vision отдаются в пространстве буфера. Чтобы маска
        // попадала на лицо на экране, X отражаем: экран = зеркало буфера.
        func display(_ p: CGPoint) -> CGPoint { CGPoint(x: 1 - p.x, y: p.y) }
        if let le = centroid(face.landmarks?.leftEye),
           let re = centroid(face.landmarks?.rightEye),
           let nose = centroid(face.landmarks?.nose) {
            return FaceInfo(boundingBox: face.boundingBox, leftEye: display(le), rightEye: display(re), noseTip: display(nose))
        }
        // Ландмарок нет — синтезируем глаза/нос из прямоугольника лица.
        let c = face.boundingBox.center
        return FaceInfo(boundingBox: face.boundingBox,
                        leftEye:  display(CGPoint(x: c.x - face.boundingBox.width * 0.18, y: c.y + face.boundingBox.height * 0.10)),
                        rightEye: display(CGPoint(x: c.x + face.boundingBox.width * 0.18, y: c.y + face.boundingBox.height * 0.10)),
                        noseTip:  display(CGPoint(x: c.x, y: c.y - face.boundingBox.height * 0.05)))
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
