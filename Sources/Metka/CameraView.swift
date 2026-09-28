import AppKit
import AVFoundation

final class CameraView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    func attach(session: AVCaptureSession) {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer?.addSublayer(preview)
    }

    override func layout() {
        super.layout()
        layer?.sublayers?.first?.frame = bounds
    }
}
