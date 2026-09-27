// Запуск из корня проекта:  swift Tools/GeneratePlaceholders.swift
// Генерирует 4 заглушки в ./Content/
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

let dir = URL(fileURLWithPath: "Content")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

func savePNG(_ image: CGImage, _ url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("не удалось создать PNG-писатель для \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("не удалось записать \(url.path)") }
    print("OK \(url.path)")
}

// Deviation: CGColor(hue:saturation:brightness:alpha:) отсутствует в CoreGraphics
// CLT SDK (это API из UIKit) — локальный перевод HSB → RGB по той же формуле.
func colorHSB(_ hue: CGFloat, _ saturation: CGFloat, _ brightness: CGFloat, _ alpha: CGFloat) -> CGColor {
    let h = hue.truncatingRemainder(dividingBy: 1)
    let i = floor(h * 6)
    let f = h * 6 - i
    let p = brightness * (1 - saturation)
    let q = brightness * (1 - f * saturation)
    let t = brightness * (1 - (1 - f) * saturation)
    switch Int(i.truncatingRemainder(dividingBy: 6)) {
    case 0: return CGColor(red: brightness, green: t, blue: p, alpha: alpha)
    case 1: return CGColor(red: q, green: brightness, blue: p, alpha: alpha)
    case 2: return CGColor(red: p, green: brightness, blue: t, alpha: alpha)
    case 3: return CGColor(red: p, green: q, blue: brightness, alpha: alpha)
    case 4: return CGColor(red: t, green: p, blue: brightness, alpha: alpha)
    default: return CGColor(red: brightness, green: p, blue: q, alpha: alpha)
    }
}

// ---------- photo.png: градиент + круги ----------
do {
    let w = 1280, h = 800
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let colors = [CGColor(red: 0.10, green: 0.20, blue: 0.60, alpha: 1),
                  CGColor(red: 0.55, green: 0.15, blue: 0.70, alpha: 1)]
    let grad = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: CGFloat(h)), options: [])
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
    for i in 0..<5 {
        let x = 160 + CGFloat(i) * 240
        ctx.fillEllipse(in: CGRect(x: x - 60, y: 400 + sin(Double(i)) * 120 - 60, width: 120, height: 120))
    }
    savePNG(ctx.makeImage()!, dir.appendingPathComponent("photo.png"))
}

// ---------- mask.png: очки + усы на прозрачном фоне ----------
do {
    let w = 800, h = 400
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
    let black = CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
    // линзы
    ctx.setStrokeColor(black); ctx.setLineWidth(22)
    ctx.strokeEllipse(in: CGRect(x: 80,  y: 210, width: 260, height: 170))
    ctx.strokeEllipse(in: CGRect(x: 460, y: 210, width: 260, height: 170))
    // перемычка
    ctx.setFillColor(black)
    ctx.fill(CGRect(x: 340, y: 280, width: 120, height: 26))
    // усы
    ctx.fillEllipse(in: CGRect(x: 250, y: 80, width: 140, height: 70))
    ctx.fillEllipse(in: CGRect(x: 410, y: 80, width: 140, height: 70))
    savePNG(ctx.makeImage()!, dir.appendingPathComponent("mask.png"))
}

// ---------- audio.wav: 8 нот, ~3.2 с ----------
do {
    let url = dir.appendingPathComponent("audio.wav")
    try? FileManager.default.removeItem(at: url)
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]
    let file = try AVAudioFile(forWriting: url, settings: settings)
    // Deviation: processingFormat у AVAudioFile всегда Float32; буфер Int16
    // (как в брифе) вызывает жёсткий abort в AudioConverter на этой системе.
    let format = file.processingFormat
    let notes = [261.63, 329.63, 392.0, 523.25, 523.25, 392.0, 329.63, 261.63]
    let noteFrames = AVAudioFrameCount(44100 * 0.4)
    for f in notes {
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: noteFrames)!
        buf.frameLength = noteFrames
        let ptr = buf.floatChannelData![0]
        for i in 0..<Int(noteFrames) {
            let t = Double(i) / 44100.0
            let env = sin(.pi * Double(i) / Double(noteFrames))       // атака/затухание ноты
            ptr[i] = Float(0.55 * env * sin(2 * .pi * f * t))
        }
        try file.write(from: buf)
    }
    print("OK \(url.path)")
}

// ---------- video.mp4: 4 с, 30 fps, движущиеся круги ----------
do {
    let url = dir.appendingPathComponent("video.mp4")
    try? FileManager.default.removeItem(at: url)
    let w = 640, h = 360, fps = Int32(30), seconds = 4
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: w,
        AVVideoHeightKey: h,
    ])
    let adapter = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
        ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    for frame in 0..<Int(fps) * seconds {
        while !input.isReadyForMoreMediaData { usleep(2000) }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &pb)
        let buffer = pb!
        CVPixelBufferLockBaseAddress(buffer, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: w, height: h,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        let t = Double(frame) / Double(fps)
        let hue = CGFloat((t / 4.0).truncatingRemainder(dividingBy: 1))
        ctx.setFillColor(colorHSB(hue, 0.7, 0.35, 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        for i in 0..<6 {
            let phase = t * 2 * Double.pi + Double(i) * .pi / 3
            let cx = 320 + 240 * cos(phase)
            let cy = 180 + 120 * sin(phase * 2)
            let ballHue = hue + CGFloat(i) * 0.08
            ctx.setFillColor(colorHSB(ballHue, 0.8, 1, 1))
            ctx.fillEllipse(in: CGRect(x: cx - 40, y: cy - 40, width: 80, height: 80))
        }
        ctx.flush()
        CVPixelBufferUnlockBaseAddress(buffer, [])
        adapter.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
    }
    input.markAsFinished()
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    guard writer.status == .completed else { fatalError("видео не записалось: \(String(describing: writer.error))") }
    print("OK \(url.path)")
}
