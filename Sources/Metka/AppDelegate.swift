import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let camera = CameraController()
    private var cameraView: CameraView?
    private var stabilizer = GestureStabilizer() // 15 кадров вкл / 8 выкл (~0.5 с / ~0.27 с)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = CameraView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        view.autoresizingMask = [.width, .height]
        view.attach(session: camera.session)
        cameraView = view

        camera.onStatus = { status in
            print("камера: \(status)")
        }
        camera.onFrame = { [weak self] observation in
            guard let self else { return }
            let raw = observation.handPoints.flatMap { GestureClassifier.classify($0) }
            let stable = self.stabilizer.feed(raw)
            if raw != nil || stable != nil || observation.face != nil {
                print("жест: \(raw?.rawValue ?? "—") | стабильный: \(stable?.rawValue ?? "—") | лицо: \(observation.face != nil ? "да" : "нет")")
            }
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
}
