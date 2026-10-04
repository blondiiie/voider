import AppKit
import AVFoundation

final class OverlayView: NSView {
    // Константы посадки маски — калибруются под конкретный mask.png.
    var maskWidthFactor: CGFloat = 3.6      // ширина маски = межглазное расстояние × коэффициент
    var maskDropFactor: CGFloat = 0.55      // опустить центр маски ниже линии глаз

    private let gestureLabel = OverlayView.label(fontSize: 20)
    private let faceLabel = OverlayView.label(fontSize: 16)
    private let hintLabel = OverlayView.label(fontSize: 13)
    private let cameraStatusLabel = OverlayView.label(fontSize: 18)

    private let maskLayer = CALayer()
    private var maskAspect: CGFloat = 2.0   // ширина/высота mask.png

    private let photoLayer = CALayer()
    private var playerLayer: AVPlayerLayer?
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var audioPlayer: AVAudioPlayer?
    private var audioIndicator: CALayer?
    private var currentKind: ContentKind = .idle

    // ВАЖНО: все слои-оверлеи создаются и добавляются здесь, в init.
    // Слои, добавленные в слой layer-backed вида после установки в окно,
    // в этой конфигурации не отрисовывались — проверено эмпирически.
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

        if let url = ContentLoader.photoURL,
           let image = NSImage(contentsOf: url),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            photoLayer.contents = cg
            let maxHeight = min(420, CGFloat(cg.height))
            let width = maxHeight * CGFloat(cg.width) / CGFloat(cg.height)
            photoLayer.bounds = CGRect(x: 0, y: 0, width: width, height: maxHeight)
            photoLayer.cornerRadius = 16
            photoLayer.masksToBounds = true
            photoLayer.shadowColor = NSColor.black.cgColor
            photoLayer.shadowOpacity = 0.6
            photoLayer.shadowRadius = 18
            photoLayer.shadowOffset = CGSize(width: 0, height: -6)
        }
        photoLayer.opacity = 0
        photoLayer.isHidden = true
        layer?.addSublayer(photoLayer)

        if let url = ContentLoader.videoURL {
            let player = AVQueuePlayer()
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            let pl = AVPlayerLayer(player: player)
            pl.cornerRadius = 14
            pl.masksToBounds = true
            pl.frame = centeredVideoRect()
            pl.opacity = 0
            pl.isHidden = true
            layer?.addSublayer(pl)
            playerLayer = pl
            queuePlayer = player
        }

        if let url = ContentLoader.audioURL {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
        }

        let container = CALayer()
        container.backgroundColor = NSColor(white: 0, alpha: 0.55).cgColor
        container.cornerRadius = 14
        let label = CATextLayer()
        label.string = "🔊 Аудио"
        label.fontSize = 18
        label.foregroundColor = NSColor.white.cgColor
        label.alignmentMode = .center
        label.frame = CGRect(x: 0, y: 46, width: 180, height: 30)
        container.addSublayer(label)
        for i in 0..<4 {
            let bar = CALayer()
            bar.frame = CGRect(x: CGFloat(20 + i * 38), y: 16, width: 18, height: 20)
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = 4
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = 0.4
            anim.toValue = 2.2
            anim.duration = 0.35 + Double(i) * 0.09
            anim.autoreverses = true
            anim.repeatCount = .infinity
            bar.add(anim, forKey: "bounce")
            container.addSublayer(bar)
        }
        container.frame = CGRect(x: bounds.midX - 90, y: bounds.midY - 45, width: 180, height: 90)
        container.isHidden = true
        layer?.addSublayer(container)
        audioIndicator = container
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
        gestureLabel.sizeToFit()
        faceLabel.stringValue = "Лицо: \(faceSeen ? "найдено" : "нет")"
        faceLabel.sizeToFit()
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

    // ---------- Контент ----------

    func setContent(_ kind: ContentKind) {
        guard kind != currentKind else { return }
        let previous = currentKind
        currentKind = kind
        if previous == .video { stopVideo() }
        if previous == .photo { fade(photoLayer, visible: false) }
        if previous == .audio { stopAudio() }

        switch kind {
        case .idle:
            break
        case .video:
            startVideo()
        case .photo:
            guard photoLayer.contents != nil else { return }
            photoLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            fade(photoLayer, visible: true)
        case .audio:
            startAudio()
        }
    }

    private func startVideo() {
        guard let pl = playerLayer else { return }
        pl.frame = centeredVideoRect()
        queuePlayer?.seek(to: .zero)
        queuePlayer?.play()
        fade(pl, visible: true)
    }

    private func stopVideo() {
        queuePlayer?.pause()
        if let pl = playerLayer { fade(pl, visible: false) }
    }

    private func startAudio() {
        audioPlayer?.currentTime = 0
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.play()
        audioIndicator?.isHidden = false
    }

    private func stopAudio() {
        audioPlayer?.pause()
        audioIndicator?.isHidden = true
    }

    private func centeredVideoRect() -> CGRect {
        let w: CGFloat = 480, h = w * 9 / 16
        return CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
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
        playerLayer?.frame = centeredVideoRect()
        audioIndicator?.frame = CGRect(x: bounds.midX - 90, y: bounds.midY - 45, width: 180, height: 90)
    }
}
