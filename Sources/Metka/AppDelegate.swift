import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let camera = CameraController()
    private var cameraView: CameraView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = CameraView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        view.autoresizingMask = [.width, .height]
        view.attach(session: camera.session)
        cameraView = view

        camera.onStatus = { status in
            print("камера: \(status)")
        }
        camera.onFrame = { observation in
            // Task 8 подключит сюда распознавание; пока просто держим кадры.
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
