import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let camera = CameraController()
    private var cameraView: CameraView?
    private var stabilizer = GestureStabilizer()

    // Демо-режим: `open Metka.app --args -demo-cycle` — первые 10 секунд
    // после старта камеры контент сменяется сам (аудио → фото → видео).
    private let demoCycle = CommandLine.arguments.contains("-demo-cycle")
    private var demoStart: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = CameraView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        view.autoresizingMask = [.width, .height]
        view.attach(session: camera.session)

        let overlay = OverlayView(frame: view.bounds)
        overlay.autoresizingMask = [.width, .height]
        view.addSubview(overlay)
        cameraView = view

        camera.onStatus = { [weak overlay] status in
            overlay?.showCameraStatus(status)
            let missing = ContentLoader.missingDescription
            if !missing.isEmpty { print("нет ресурсов: \(missing)") }
        }
        camera.onFrame = { [weak self, weak overlay] observation in
            guard let self, let overlay else { return }
            let raw = observation.handPoints.flatMap { GestureClassifier.classify($0) }
            let stable = self.stabilizer.feed(raw)
            let mapper = CoordinateMapper(videoSize: observation.videoSize,
                                          layerSize: overlay.bounds.size)
            overlay.updateStatus(raw: raw, stable: stable, faceSeen: observation.face != nil)
            overlay.updateFace(observation.face, mapper: mapper)
            overlay.setContent(self.currentKind(stable: stable))
        }
        camera.start()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Метка"
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func currentKind(stable: HandGesture?) -> ContentKind {
        guard demoCycle else { return ContentKind.from(stable) }
        if demoStart == nil { demoStart = Date() }
        guard let start = demoStart, Date().timeIntervalSince(start) < 10 else {
            return ContentKind.from(stable)
        }
        let phases: [ContentKind] = [.audio, .photo, .video, .idle]
        return phases[min(Int(Date().timeIntervalSince(start) / 2.5), phases.count - 1)]
    }

    // Закрыли окно — завершаем приложение, иначе камера и распознавание
    // продолжают работать вхолостую (горящий индикатор камеры).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
