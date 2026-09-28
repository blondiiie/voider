import AVFoundation
import CoreVideo

enum CameraStatus: Equatable {
    case idle, requesting, running, denied, noCamera
}

final class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    var onFrame: ((FrameObservation) -> Void)?
    var onStatus: ((CameraStatus) -> Void)?

    private let processingQueue = DispatchQueue(label: "ru.ovdr.metka.vision")
    private let vision = VisionProcessor()
    private var configured = false

    func start() {
        onStatus?(.requesting)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureAndRun() : self?.onStatus?(.denied)
                }
            }
        default:
            onStatus?(.denied)
        }
    }

    private func configureAndRun() {
        if !configured { configured = configure() }
        guard configured else { onStatus?(.noCamera); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.onStatus?(.running) }
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        if let conn = output.connection(with: .video), conn.isVideoMirroringSupported {
            conn.isVideoMirrored = true // selfie-зеркало: буферы и превью согласованы
        }
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let observation = vision.process(pixelBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(observation)
        }
    }
}
