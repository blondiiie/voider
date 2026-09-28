import AppKit
import AVFoundation

final class OverlayView: NSView {
    // Константы посадки маски — подбираются в Step 5 (калибровка).
    var maskWidthFactor: CGFloat = 3.6      // ширина маски = межглазное расстояние × коэффициент
    var maskDropFactor: CGFloat = 0.55      // опустить центр маски ниже линии глаз

    private let gestureLabel = OverlayView.label(fontSize: 20)
    private let faceLabel = OverlayView.label(fontSize: 16)
    private let hintLabel = OverlayView.label(fontSize: 13)
    private let cameraStatusLabel = OverlayView.label(fontSize: 18)

    private let maskLayer = CALayer()
    private var maskAspect: CGFloat = 2.0   // ширина/высота mask.png (800×400)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for l in [gestureLabel, faceLabel, hintLabel, cameraStatusLabel] {
            addSubview(l)
        }
        cameraStatusLabel.isHidden = true
        hintLabel.stringValue = "👍 — видео · ✌️ — фото · 🖐 — аудио · лицо — маска"
        hintLabel.alignment = .center

        if let url = ContentLoader.maskURL,
           let image = NSImage(contentsOf: url),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            maskLayer.contents = cg
            maskAspect = CGFloat(cg.width) / CGFloat(cg.height)
        }
        maskLayer.opacity = 0
        maskLayer.isHidden = true
        layer?.addSublayer(maskLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    private static func label(fontSize: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = NSColor(white: 0, alpha: 0.45)
        l.drawsBackground = true
        l.wantsLayer = true
        l.layer?.cornerRadius = 8
        l.layer?.masksToBounds = true
        l.isBezeled = false
        return l
    }

    // ---------- Статусы ----------

    func showCameraStatus(_ status: CameraStatus) {
        switch status {
        case .running:
            cameraStatusLabel.isHidden = true
        case .requesting:
            cameraStatusLabel.stringValue = "Запрашиваем доступ к камере…"
            cameraStatusLabel.textColor = NSColor.systemYellow
            cameraStatusLabel.sizeToFit(); cameraStatusLabel.isHidden = false
        case .denied:
            cameraStatusLabel.stringValue = "Нет доступа к камере. Системные настройки → Конфиденциальность и безопасность → Камера → «Метка»"
            cameraStatusLabel.textColor = NSColor.systemRed
            cameraStatusLabel.sizeToFit(); cameraStatusLabel.isHidden = false
        case .noCamera:
            cameraStatusLabel.stringValue = "Камера не найдена"
            cameraStatusLabel.textColor = NSColor.systemRed
            cameraStatusLabel.sizeToFit(); cameraStatusLabel.isHidden = false
        case .idle:
            break
        }
    }

    func updateStatus(raw: HandGesture?, stable: HandGesture?, faceSeen: Bool) {
        gestureLabel.stringValue = "Жест: \(stable?.rawValue ?? raw?.rawValue ?? "—")\(stable == nil && raw != nil ? " (удержите)" : "")"
        faceLabel.stringValue = "Лицо: \(faceSeen ? "найдено" : "нет")"
    }

    // ---------- Маска ----------

    func updateFace(_ face: FaceInfo?, mapper: CoordinateMapper) {
        guard let face, maskLayer.contents != nil else {
            fade(maskLayer, visible: false)
            return
        }
        let left = mapper.point(face.leftEye)
        let right = mapper.point(face.rightEye)
        let eyeDistance = hypot(left.x - right.x, left.y - right.y)
        let width = eyeDistance * maskWidthFactor
        let height = width / maskAspect
        let center = CGPoint(x: (left.x + right.x) / 2,
                             y: (left.y + right.y) / 2 - eyeDistance * maskDropFactor)
        CATransaction.begin()
        CATransaction.setDisableActions(true) // маска следует за лицом без «плаваний»
        maskLayer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        maskLayer.position = center
        maskLayer.setAffineTransform(
            CGAffineTransform(rotationAngle: atan2(right.y - left.y, right.x - left.x)))
        CATransaction.commit()
        fade(maskLayer, visible: true)
    }

    // ---------- Контент (ветки видео/фото/аудио — Task 10) ----------

    func setContent(_ kind: ContentKind) {
        if kind != .idle { print("контент: \(kind)") }
    }

    // ---------- Общее ----------

    private func fade(_ l: CALayer, visible: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        l.opacity = visible ? 1 : 0
        CATransaction.commit()
        if !visible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if l.opacity == 0 { l.isHidden = true }
            }
        } else {
            l.isHidden = false
        }
    }

    override func layout() {
        super.layout()
        gestureLabel.setFrameOrigin(NSPoint(x: 12, y: bounds.height - 40))
        faceLabel.setFrameOrigin(NSPoint(x: 12, y: bounds.height - 70))
        hintLabel.frame = CGRect(x: (bounds.width - 520) / 2, y: 12, width: 520, height: 24)
        cameraStatusLabel.frame = CGRect(x: 20, y: bounds.height / 2 - 15, width: bounds.width - 40, height: 30)
    }
}
