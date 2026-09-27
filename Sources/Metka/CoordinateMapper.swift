import CoreGraphics

/// Перевод нормализованных координат Vision (origin снизу-слева) в координаты
/// CALayer превью (оси Y тоже вверх) с учётом aspectFill-масштабирования.
struct CoordinateMapper {
    let videoSize: CGSize
    let layerSize: CGSize

    init(videoSize: CGSize, layerSize: CGSize) {
        self.videoSize = videoSize
        self.layerSize = layerSize
    }

    private var scale: CGFloat {
        max(layerSize.width / videoSize.width, layerSize.height / videoSize.height)
    }

    private var offset: CGPoint {
        CGPoint(x: (layerSize.width - videoSize.width * scale) / 2,
                y: (layerSize.height - videoSize.height * scale) / 2)
    }

    func point(_ v: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + v.x * videoSize.width * scale,
                y: offset.y + v.y * videoSize.height * scale)
    }

    func rect(_ r: CGRect) -> CGRect {
        CGRect(origin: point(r.origin),
               size: CGSize(width: r.width * videoSize.width * scale,
                            height: r.height * videoSize.height * scale))
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot((a.x - b.x) * videoSize.width * scale,
              (a.y - b.y) * videoSize.height * scale)
    }
}
