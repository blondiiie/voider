# Метка (AR-плеер по меткам) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Нативное macOS-приложение на Swift, которое через камеру распознаёт лицо и жесты (Vision) и показывает привязанный контент: маску на лице, видео, фото или аудио.

**Architecture:** Одно окно AppKit: слой превью камеры (AVCaptureSession + AVCaptureVideoPreviewLayer) и поверх него слой-оверлей (маска/видео/фото/индикатор аудио). Кадры из AVCaptureVideoDataOutput идут в Vision (лицо + жесты), чистая логика (классификация жестов, антидребезг, маппинг координат) вынесена в отдельные тестируемые структуры. Сборка без Xcode: SwiftPM → `build.sh` собирает `Metka.app` с Info.plist и ad-hoc подписью.

**Tech Stack:** Swift 5.9+, AppKit, AVFoundation, Vision, AVKit (AVQueuePlayer + AVPlayerLooper), XCTest (только чистая логика), bash для сборки .app.

## Global Constraints

- macOS 13+, только Command Line Tools (без .xcodeproj, без установки Xcode).
- Ноль сторонних зависимостей — только системные фреймворки.
- Имена контентных файлов фиксированы (ищутся в `Contents/Resources` бандла, в порядке приоритета):
  - видео: `video.mp4`, `video.mov`, `video.webm`
  - фото: `photo.jpg`, `photo.jpeg`, `photo.png`
  - аудио: `audio.mp3`, `audio.wav`, `audio.m4a`, `audio.aiff`
  - маска: `mask.png` (обязательно с прозрачностью)
- Привязка меток: лицо → маска; 👍 (Thumb_Up) → видео; ✌️ (Victory) → фото; 🖐 (Open_Palm) → аудио.
- Поведение: жест удерживается ~0,5 с (15 кадров при 30 fps) для активации, 8 кадров отсутствия для деактивации; контент живёт, пока жест в кадре; видео/фото/аудио взаимоисключающие; маска независима.
- Интерфейс на русском.
- Сборка одной командой `./build.sh`, запуск `open Metka.app`. Коммит после каждой задачи.
- Имена в коде: пакет/исполняемый файл `Metka`, отображаемое имя «Метка», bundle id `ru.ovdr.metka`.

## File Structure

```
ОВиДР/
├── Package.swift                     # SwiftPM: executable Metka + тесты
├── build.sh                          # сборка .app (binary + ресурсы + Info.plist + codesign)
├── README.md                         # инструкция: сборка, запуск, замена контента
├── .gitignore
├── Content/                          # контент пользователя (вшивается при сборке)
│   └── README.md                     # какие файлы класть
├── Tools/
│   └── GeneratePlaceholders.swift    # генерация 4 заглушек (запуск: swift Tools/...)
├── Sources/Metka/
│   ├── main.swift                    # точка входа NSApplication
│   ├── AppDelegate.swift             # окно, компоновка, связка камеры→логики→оверлея
│   ├── CameraController.swift        # AVCaptureSession, разрешения, выдача кадров
│   ├── CameraView.swift              # NSView с AVCaptureVideoPreviewLayer
│   ├── VisionProcessor.swift         # VNDetectFaceLandmarks2D + VNDetectHumanHandPose
│   ├── GestureClassifier.swift       # чистая геометрия: 👍/✌️/🖐 по 21 точке
│   ├── GestureStabilizer.swift       # антидребезг (activate/release кадры)
│   ├── ContentKind.swift             # стабилизированный жест → тип контента
│   ├── CoordinateMapper.swift        # нормализованные координаты Vision → координаты слоя
│   ├── OverlayView.swift             # слои: маска, видео, фото, индикатор аудио, статусы
│   └── ContentLoader.swift           # поиск контентных файлов в бандле
└── Tests/MetkaTests/
    ├── SmokeTests.swift
    ├── GestureClassifierTests.swift
    ├── GestureStabilizerTests.swift
    ├── ContentKindTests.swift
    └── CoordinateMapperTests.swift
```

---

### Task 1: Каркас проекта — окно приложения собирается и запускается

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/Metka/main.swift`
- Create: `Sources/Metka/AppDelegate.swift`
- Test: `Tests/MetkaTests/SmokeTests.swift`

**Interfaces:**
- Produces: исполняемая цель `Metka`; `AppDelegate` — последующие задачи добавляют ему поля в Task 8. Остальным задачам из Task 1 нужен только собирающийся пакет.

- [ ] **Step 1: git init и служебные файлы**

```bash
cd "/Users/macbookair/Documents/ОВиДР"
git init
```

`.gitignore`:
```
.build/
Metka.app/
.DS_Store
*.o
*.d
```

- [ ] **Step 2: Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Metka",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Metka", path: "Sources/Metka"),
        .testTarget(name: "MetkaTests", dependencies: ["Metka"], path: "Tests/MetkaTests"),
    ]
)
```

- [ ] **Step 3: main.swift**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
```

- [ ] **Step 4: AppDelegate.swift (минимальный — просто окно)**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Метка"
        window.contentView = NSView()
        window.contentView?.wantsLayer = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
```

- [ ] **Step 5: SmokeTests.swift**

```swift
import XCTest
@testable import Metka

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 6: Проверить сборку и тесты**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -5`
Expected: `Build complete!` и `Executed 1 test, with 0 failures`.

- [ ] **Step 7: Проверить запуск (окно появляется и закрывается само)**

Run: `swift build && timeout 5 ./.build/debug/Metka; echo "exit: $?"`
Expected: `exit: 124` (процесс работал 5 секунд и был снят по таймауту, значит не упал при старте).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: каркас Metka — окно AppKit, SwiftPM, smoke-тест"
```

---

### Task 2: GestureClassifier — классификация жестов по 21 точке (TDD)

**Files:**
- Create: `Sources/Metka/GestureClassifier.swift`
- Test: `Tests/MetkaTests/GestureClassifierTests.swift`

**Interfaces:**
- Consumes: `VNHumanHandPoseObservation.JointName` (Vision).
- Produces:
  - `enum HandGesture: String { case thumbUp = "👍", victory = "✌️", openPalm = "🖐" }`
  - `enum GestureClassifier { static func classify(_ p: [VNHumanHandPoseObservation.JointName: CGPoint]) -> HandGesture?; static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat; static func isFingerExtended(tip:pip:wrist:) -> Bool; static func isThumbExtended(tip:mp:indexMCP:) -> Bool }`

- [ ] **Step 1: Написать failing-тесты**

`Tests/MetkaTests/GestureClassifierTests.swift`:
```swift
import XCTest
import CoreGraphics
import Vision
@testable import Metka

final class GestureClassifierTests: XCTestCase {
    // Координаты Vision: нормализованные 0..1, ось Y вверх, origin снизу-слева.

    private func openPalm() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        [
            .wrist:      CGPoint(x: 0.50, y: 0.10),
            .thumbCMC:   CGPoint(x: 0.42, y: 0.16),
            .thumbMP:    CGPoint(x: 0.36, y: 0.26),
            .thumbTIP:   CGPoint(x: 0.31, y: 0.36),
            .indexMCP:   CGPoint(x: 0.43, y: 0.34),
            .indexPIP:   CGPoint(x: 0.41, y: 0.46),
            .indexDIP:   CGPoint(x: 0.40, y: 0.55),
            .indexTIP:   CGPoint(x: 0.39, y: 0.62),
            .middleMCP:  CGPoint(x: 0.49, y: 0.35),
            .middlePIP:  CGPoint(x: 0.49, y: 0.49),
            .middleDIP:  CGPoint(x: 0.49, y: 0.59),
            .middleTIP:  CGPoint(x: 0.49, y: 0.67),
            .ringMCP:    CGPoint(x: 0.55, y: 0.33),
            .ringPIP:    CGPoint(x: 0.56, y: 0.46),
            .ringDIP:    CGPoint(x: 0.57, y: 0.55),
            .ringTIP:    CGPoint(x: 0.58, y: 0.62),
            .littleMCP:  CGPoint(x: 0.60, y: 0.29),
            .littlePIP:  CGPoint(x: 0.62, y: 0.38),
            .littleDIP:  CGPoint(x: 0.63, y: 0.44),
            .littleTIP:  CGPoint(x: 0.64, y: 0.49),
        ]
    }

    private func victory() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        var p = openPalm()
        // сгибаем безымянный и мизинец
        p[.ringTIP]   = CGPoint(x: 0.52, y: 0.36)
        p[.littleTIP] = CGPoint(x: 0.56, y: 0.30)
        return p
    }

    private func thumbUp() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        [
            .wrist:      CGPoint(x: 0.50, y: 0.10),
            .thumbCMC:   CGPoint(x: 0.42, y: 0.16),
            .thumbMP:    CGPoint(x: 0.44, y: 0.34),
            .thumbTIP:   CGPoint(x: 0.46, y: 0.62),
            .indexMCP:   CGPoint(x: 0.53, y: 0.22),
            .indexPIP:   CGPoint(x: 0.55, y: 0.32),
            .indexDIP:   CGPoint(x: 0.55, y: 0.28),
            .indexTIP:   CGPoint(x: 0.55, y: 0.24),
            .middleMCP:  CGPoint(x: 0.50, y: 0.20),
            .middlePIP:  CGPoint(x: 0.50, y: 0.34),
            .middleDIP:  CGPoint(x: 0.50, y: 0.30),
            .middleTIP:  CGPoint(x: 0.50, y: 0.26),
            .ringMCP:    CGPoint(x: 0.47, y: 0.19),
            .ringPIP:    CGPoint(x: 0.45, y: 0.32),
            .ringDIP:    CGPoint(x: 0.45, y: 0.28),
            .ringTIP:    CGPoint(x: 0.45, y: 0.24),
            .littleMCP:  CGPoint(x: 0.44, y: 0.17),
            .littlePIP:  CGPoint(x: 0.41, y: 0.29),
            .littleDIP:  CGPoint(x: 0.41, y: 0.25),
            .littleTIP:  CGPoint(x: 0.41, y: 0.22),
        ]
    }

    private func fist() -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        var p = thumbUp()
        p[.thumbTIP] = CGPoint(x: 0.44, y: 0.30) // большой палец прижат
        return p
    }

    func testOpenPalm() {
        XCTAssertEqual(GestureClassifier.classify(openPalm()), .openPalm)
    }

    func testVictory() {
        XCTAssertEqual(GestureClassifier.classify(victory()), .victory)
    }

    func testThumbUp() {
        XCTAssertEqual(GestureClassifier.classify(thumbUp()), .thumbUp)
    }

    func testFistIsNil() {
        XCTAssertNil(GestureClassifier.classify(fist()))
    }

    func testEmptyIsNil() {
        XCTAssertNil(GestureClassifier.classify([:]))
    }

    func testDistance() {
        XCTAssertEqual(GestureClassifier.distance(CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)), 5, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Запустить, убедиться что падает**

Run: `swift test --filter GestureClassifierTests 2>&1 | tail -5`
Expected: ошибка компиляции `'GestureClassifier' is undefined` (или cannot find) — тесты не собираются, это и есть FAIL.

- [ ] **Step 3: Реализация**

`Sources/Metka/GestureClassifier.swift`:
```swift
import CoreGraphics
import Vision

enum HandGesture: String {
    case thumbUp = "👍"
    case victory = "✌️"
    case openPalm = "🖐"
}

enum GestureClassifier {
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Палец выпрямлен, если его кончик дальше от запястья, чем средний сустав (инвариант к повороту кисти).
    static func isFingerExtended(tip: CGPoint, pip: CGPoint, wrist: CGPoint) -> Bool {
        distance(tip, wrist) > distance(pip, wrist) * 1.15
    }

    /// Большой выпрямлен, если кончик заметно дальше от основания указательного, чем его средний сустав.
    static func isThumbExtended(tip: CGPoint, mp: CGPoint, indexMCP: CGPoint) -> Bool {
        distance(tip, indexMCP) > distance(mp, indexMCP) * 1.2
    }

    static func classify(_ p: [VNHumanHandPoseObservation.JointName: CGPoint]) -> HandGesture? {
        guard let wrist = p[.wrist],
              let iMCP = p[.indexMCP], let iTIP = p[.indexTIP], let iPIP = p[.indexPIP],
              let mTIP = p[.middleTIP], let mPIP = p[.middlePIP],
              let rTIP = p[.ringTIP], let rPIP = p[.ringPIP],
              let lTIP = p[.littleTIP], let lPIP = p[.littlePIP],
              let tTIP = p[.thumbTIP], let tMP = p[.thumbMP] else { return nil }

        let index  = isFingerExtended(tip: iTIP, pip: iPIP, wrist: wrist)
        let middle = isFingerExtended(tip: mTIP, pip: mPIP, wrist: wrist)
        let ring   = isFingerExtended(tip: rTIP, pip: rPIP, wrist: wrist)
        let little = isFingerExtended(tip: lTIP, pip: lPIP, wrist: wrist)
        let thumb  = isThumbExtended(tip: tTIP, mp: tMP, indexMCP: iMCP)

        if index && middle && ring && little { return .openPalm }
        if index && middle && !ring && !little { return .victory }
        if thumb && !index && !middle && !ring && !little && tTIP.y > wrist.y + 0.15 {
            return .thumbUp
        }
        return nil
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `swift test --filter GestureClassifierTests 2>&1 | tail -3`
Expected: `Executed 6 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Metka/GestureClassifier.swift Tests/MetkaTests/GestureClassifierTests.swift
git commit -m "feat: классификатор жестов 👍/✌️/🖐 по 21 точке Vision"
```

---

### Task 3: GestureStabilizer — антидребезг (TDD)

**Files:**
- Create: `Sources/Metka/GestureStabilizer.swift`
- Test: `Tests/MetkaTests/GestureStabilizerTests.swift`

**Interfaces:**
- Consumes: `HandGesture` из Task 2.
- Produces: `struct GestureStabilizer { init(activateFrames: Int = 15, releaseFrames: Int = 8); mutating func feed(_ observed: HandGesture?) -> HandGesture?; private(set) var stable: HandGesture? }` — `feed` возвращает текущий стабилизированный жест.

- [ ] **Step 1: Failing-тесты**

`Tests/MetkaTests/GestureStabilizerTests.swift`:
```swift
import XCTest
@testable import Metka

final class GestureStabilizerTests: XCTestCase {
    func testActivateAfterNFrames() {
        var s = GestureStabilizer(activateFrames: 3, releaseFrames: 2)
        XCTAssertNil(s.feed(.victory))
        XCTAssertNil(s.feed(.victory))
        XCTAssertEqual(s.feed(.victory), .victory, "активация на 3-м кадре")
    }

    func testInterruptedSequenceDoesNotActivate() {
        var s = GestureStabilizer(activateFrames: 3, releaseFrames: 2)
        _ = s.feed(.victory); _ = s.feed(.victory); _ = s.feed(nil)
        XCTAssertNil(s.feed(.victory), "счётчик сброшен — нужно снова 3 кадра")
        XCTAssertNil(s.feed(.victory))
        XCTAssertEqual(s.feed(.victory), .victory)
    }

    func testSwitchGestureRequiresNewStreak() {
        var s = GestureStabilizer(activateFrames: 2, releaseFrames: 2)
        _ = s.feed(.victory); XCTAssertEqual(s.feed(.victory), .victory)
        XCTAssertEqual(s.feed(.thumbUp), .victory, "пока держится старый")
        _ = s.feed(.thumbUp)
        XCTAssertEqual(s.feed(.thumbUp), .thumbUp, "новый набрал серию")
    }

    func testReleaseAfterMFrames() {
        var s = GestureStabilizer(activateFrames: 2, releaseFrames: 2)
        _ = s.feed(.openPalm); _ = s.feed(.openPalm)
        XCTAssertEqual(s.feed(nil), .openPalm, "1 кадр отсутствия — ещё держим")
        XCTAssertNil(s.feed(nil), "2 кадра отсутствия — отпустили")
    }

    func testNilNeverActivates() {
        var s = GestureStabilizer(activateFrames: 2, releaseFrames: 2)
        XCTAssertNil(s.feed(nil)); XCTAssertNil(s.feed(nil))
    }
}
```

- [ ] **Step 2: Запустить, убедиться что падает**

Run: `swift test --filter GestureStabilizerTests 2>&1 | tail -5`
Expected: ошибка компиляции `cannot find 'GestureStabilizer'`.

- [ ] **Step 3: Реализация**

`Sources/Metka/GestureStabilizer.swift`:
```swift
/// Антидребезг: жест становится «стабильным» после activateFrames подряд
/// одинаковых наблюдений и отпускается после releaseFrames подряд пустых.
struct GestureStabilizer {
    let activateFrames: Int
    let releaseFrames: Int

    private(set) var stable: HandGesture?
    private var candidate: HandGesture?
    private var candidateCount = 0
    private var absenceCount = 0

    init(activateFrames: Int = 15, releaseFrames: Int = 8) {
        self.activateFrames = max(1, activateFrames)
        self.releaseFrames = max(1, releaseFrames)
    }

    mutating func feed(_ observed: HandGesture?) -> HandGesture? {
        if let gesture = observed {
            absenceCount = 0
            if gesture == candidate {
                candidateCount += 1
            } else {
                candidate = gesture
                candidateCount = 1
            }
            if candidateCount >= activateFrames {
                stable = candidate
            }
        } else if let current = stable {
            candidate = nil
            candidateCount = 0
            absenceCount += 1
            if absenceCount >= releaseFrames {
                stable = nil
            }
        } else {
            candidate = nil
            candidateCount = 0
            absenceCount = 0
        }
        return stable
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `swift test --filter GestureStabilizerTests 2>&1 | tail -3`
Expected: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Metka/GestureStabilizer.swift Tests/MetkaTests/GestureStabilizerTests.swift
git commit -m "feat: стабилизатор жестов — удержание 15 кадров, отпускание 8"
```

---

### Task 4: ContentKind — стабилизированный жест → тип контента (TDD)

**Files:**
- Create: `Sources/Metka/ContentKind.swift`
- Test: `Tests/MetkaTests/ContentKindTests.swift`

**Interfaces:**
- Consumes: `HandGesture` из Task 2.
- Produces: `enum ContentKind: Equatable { case idle, video, photo, audio; static func from(_ gesture: HandGesture?) -> ContentKind }`.

- [ ] **Step 1: Failing-тесты**

`Tests/MetkaTests/ContentKindTests.swift`:
```swift
import XCTest
@testable import Metka

final class ContentKindTests: XCTestCase {
    func testMapping() {
        XCTAssertEqual(ContentKind.from(.thumbUp), .video)
        XCTAssertEqual(ContentKind.from(.victory), .photo)
        XCTAssertEqual(ContentKind.from(.openPalm), .audio)
        XCTAssertEqual(ContentKind.from(nil), .idle)
    }
}
```

- [ ] **Step 2: Запустить, убедиться что падает**

Run: `swift test --filter ContentKindTests 2>&1 | tail -5`
Expected: `cannot find 'ContentKind'`.

- [ ] **Step 3: Реализация**

`Sources/Metka/ContentKind.swift`:
```swift
enum ContentKind: Equatable {
    case idle
    case video
    case photo
    case audio

    static func from(_ gesture: HandGesture?) -> ContentKind {
        switch gesture {
        case .thumbUp:  return .video
        case .victory:  return .photo
        case .openPalm: return .audio
        case nil:       return .idle
        }
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `swift test --filter ContentKindTests 2>&1 | tail -3`
Expected: `Executed 1 test, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Metka/ContentKind.swift Tests/MetkaTests/ContentKindTests.swift
git commit -m "feat: маппинг жест → тип контента"
```

---

### Task 5: CoordinateMapper — координаты Vision → координаты слоя (TDD)

**Files:**
- Create: `Sources/Metka/CoordinateMapper.swift`
- Test: `Tests/MetkaTests/CoordinateMapperTests.swift`

**Interfaces:**
- Produces: `struct CoordinateMapper { init(videoSize: CGSize, layerSize: CGSize); func point(_ v: CGPoint) -> CGPoint; func rect(_ r: CGRect) -> CGRect; func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat }`. Вход: нормализованные координаты Vision (0..1, origin снизу-слева). Выход: координаты CALayer (points, ось Y вверх). Учёт aspectFill и зеркала не требуется: буферы приходят уже зеркальными (selfie), превью показывает тот же буфер.

- [ ] **Step 1: Failing-тесты**

`Tests/MetkaTests/CoordinateMapperTests.swift`:
```swift
import XCTest
import CoreGraphics
@testable import Metka

final class CoordinateMapperTests: XCTestCase {
    // видео 1000x500 в слое 500x500: scale = 1, offsetX = -250, offsetY = 0
    private var mapper: CoordinateMapper {
        CoordinateMapper(videoSize: CGSize(width: 1000, height: 500),
                         layerSize: CGSize(width: 500, height: 500))
    }

    func testPointCorners() {
        let m = mapper
        XCTAssertEqual(m.point(CGPoint(x: 0, y: 0)), CGPoint(x: -250, y: 0))
        XCTAssertEqual(m.point(CGPoint(x: 1, y: 1)), CGPoint(x: 750, y: 500))
    }

    func testPointCenter() {
        let m = mapper
        XCTAssertEqual(m.point(CGPoint(x: 0.5, y: 0.5)), CGPoint(x: 250, y: 250))
    }

    func testRect() {
        let m = mapper
        let r = m.rect(CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        XCTAssertEqual(r, CGRect(x: 0, y: 125, width: 500, height: 250))
    }

    func testDistance() {
        let m = mapper
        XCTAssertEqual(m.distance(CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)),
                       1118.03, accuracy: 0.1) // hypot(1000, 500)
    }
}
```

- [ ] **Step 2: Запустить, убедиться что падает**

Run: `swift test --filter CoordinateMapperTests 2>&1 | tail -5`
Expected: `cannot find 'CoordinateMapper'`.

- [ ] **Step 3: Реализация**

`Sources/Metka/CoordinateMapper.swift`:
```swift
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
```

- [ ] **Step 4: Прогнать тесты**

Run: `swift test --filter CoordinateMapperTests 2>&1 | tail -3`
Expected: `Executed 4 tests, with 0 failures`.

- [ ] **Step 5: Прогнать ВСЕ тесты**

Run: `swift test 2>&1 | tail -3`
Expected: `Executed 17 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Metka/CoordinateMapper.swift Tests/MetkaTests/CoordinateMapperTests.swift
git commit -m "feat: маппинг координат Vision → слой с aspectFill"
```

---

### Task 6: Заглушки контента + Content/README

**Files:**
- Create: `Tools/GeneratePlaceholders.swift`
- Create: `Content/README.md`

**Interfaces:**
- Produces: файлы `Content/photo.png`, `Content/mask.png`, `Content/audio.wav`, `Content/video.mp4` (генерируются запуском `swift Tools/GeneratePlaceholders.swift` из корня проекта). Используются Task 9–10 через `ContentLoader` и вшиваются в .app задачей 11. Финальная сборка — на файлах пользователя с теми же именами.

- [ ] **Step 1: Content/README.md**

```markdown
# Контент приложения «Метка»

Положите сюда свои файлы (ровно по одному на тип). При `./build.sh` они
вшиваются внутрь `Metka.app/Contents/Resources/`.

- `video.mp4` (или `.mov`, `.webm`) — видео по жесту 👍
- `photo.jpg` (или `.jpeg`, `.png`) — фото по жесту ✌️
- `audio.mp3` (или `.wav`, `.m4a`, `.aiff`) — аудио по жесту 🖐
- `mask.png` — маска на лицо (ОБЯЗАТЕЛЬНО с прозрачным фоном)

Если каких-то файлов нет, запустите `swift Tools/GeneratePlaceholders.swift` —
он сгенерирует временные заглушки.
```

- [ ] **Step 2: Tools/GeneratePlaceholders.swift — полный код**

```swift
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
    let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)!
    let notes = [261.63, 329.63, 392.0, 523.25, 523.25, 392.0, 329.63, 261.63]
    let noteFrames = AVAudioFrameCount(44100 * 0.4)
    for f in notes {
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: noteFrames)!
        buf.frameLength = noteFrames
        let ptr = buf.int16ChannelData![0]
        for i in 0..<Int(noteFrames) {
            let t = Double(i) / 44100.0
            let env = sin(.pi * Double(i) / Double(noteFrames))       // атака/затухание ноты
            ptr[i] = Int16(0.55 * env * sin(2 * .pi * f * t) * Double(Int16.max))
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
        ctx.setFillColor(CGColor(hue: hue, saturation: 0.7, brightness: 0.35, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        for i in 0..<6 {
            let phase = t * 2 * Double.pi + Double(i) * .pi / 3
            let cx = 320 + 240 * cos(phase)
            let cy = 180 + 120 * sin(phase * 2)
            ctx.setFillColor(CGColor(hue: hue + CGFloat(i) * 0.08, saturation: 0.8, brightness: 1, alpha: 1))
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
```

- [ ] **Step 3: Запустить генератор**

Run: `cd "/Users/macbookair/Documents/ОВиДР" && swift Tools/GeneratePlaceholders.swift && ls -la Content/`
Expected: четыре строки `OK Content/...` и в списке файлов `audio.wav`, `mask.png`, `photo.png`, `video.mp4` (каждый больше 0 байт).

- [ ] **Step 4: Commit**

```bash
git add Tools/GeneratePlaceholders.swift Content/README.md Content/
git commit -m "feat: генератор заглушек контента (видео/фото/аудио/маска)"
```

---

### Task 7: Камера — превью в окне + разрешения

**Files:**
- Create: `Sources/Metka/CameraController.swift`
- Create: `Sources/Metka/CameraView.swift`
- Create: `Sources/Metka/VisionProcessor.swift` (каркас `FrameObservation`/`FaceInfo`, детекция появится здесь же в Task 8)
- Modify: `Sources/Metka/AppDelegate.swift` (заменить целиком)

**Interfaces:**
- Produces:
  - `enum CameraStatus: Equatable { case idle, requesting, running, denied, noCamera }`
  - `final class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate { let session: AVCaptureSession; var onFrame: ((FrameObservation) -> Void)?; var onStatus: ((CameraStatus) -> Void)?; func start() }` — `onFrame`/`onStatus` вызываются в main queue.
  - `final class CameraView: NSView { func attach(session: AVCaptureSession) }`
  - `struct FrameObservation { let face: FaceInfo?; let handPoints: [VNHumanHandPoseObservation.JointName: CGPoint]?; let videoSize: CGSize }` и `struct FaceInfo { let boundingBox: CGRect; let leftEye: CGPoint; let rightEye: CGPoint; let noseTip: CGPoint }` (глаза/нос — нормализованные центры; если ландмарки не найдены — синтезируются из boundingBox).
  - В Task 7 `VisionProcessor.process` возвращает заготовку (пустое наблюдение), реальная детекция — Task 8, подписи не меняются.

- [ ] **Step 1: VisionProcessor.swift — типы и каркас**

```swift
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
    func process(_ pixelBuffer: CVPixelBuffer) -> FrameObservation {
        // Task 8 добавит сюда face/hand запросы; сейчас — размеры кадра.
        FrameObservation(
            face: nil,
            handPoints: nil,
            videoSize: CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                              height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        )
    }
}
```

- [ ] **Step 2: CameraController.swift**

```swift
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
```

- [ ] **Step 3: CameraView.swift**

```swift
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
```

- [ ] **Step 4: AppDelegate.swift (заменить целиком)**

```swift
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
```

- [ ] **Step 5: Сборка и тесты**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, `Executed 17 tests, with 0 failures`.

- [ ] **Step 6: MANUAL CHECK — превью камеры (нужен человек у камеры)**

Собрать упрощённый запуск без бандла нельзя (нет Info.plist → камера недоступна), поэтому сразу используем минимальный сборщик:

```bash
cd "/Users/macbookair/Documents/ОВиДР"
swift build -c release
rm -rf Metka.app && mkdir -p Metka.app/Contents/MacOS
cp .build/release/Metka Metka.app/Contents/MacOS/
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<plist version="1.0"><dict>' \
  '<key>CFBundleName</key><string>Метка</string>' \
  '<key>CFBundleIdentifier</key><string>ru.ovdr.metka</string>' \
  '<key>CFBundleExecutable</key><string>Metka</string>' \
  '<key>CFBundlePackageType</key><string>APPL</string>' \
  '<key>NSCameraUsageDescription</key><string>Приложение распознаёт лицо и жесты через камеру.</string>' \
  '</dict></plist>' > Metka.app/Contents/Info.plist
codesign --force --sign - Metka.app
open Metka.app
```

Expected: системный диалог «"Метка" запрашивает доступ к камере» → «Разрешить» → в окне живое видео с фронтальной камеры (зеркальное). В логе (Console/терминал) — `камера: running`. Если доступ был случайно запрещён: Системные настройки → Конфиденциальность и безопасность → Камера → включить «Метка», перезапустить приложение.

- [ ] **Step 7: Commit**

```bash
git add Sources/Metka/CameraController.swift Sources/Metka/CameraView.swift Sources/Metka/VisionProcessor.swift Sources/Metka/AppDelegate.swift
git commit -m "feat: камера — превью, разрешения, конвейер кадров"
```

---

### Task 8: Распознавание — Vision на каждом кадре, статусы жеста и лица

**Files:**
- Modify: `Sources/Metka/VisionProcessor.swift` (заменить тело `process`)
- Modify: `Sources/Metka/AppDelegate.swift` (заменить целиком)

**Interfaces:**
- Consumes: `GestureClassifier`, `GestureStabilizer`, `ContentKind`, `FrameObservation` из задач 2–5, 7.
- Produces: живой конвейер кадр → `HandGesture?` → стабилизатор → `ContentKind`. `VisionProcessor.process` — сигнатура прежняя, теперь реально детектирует. Статусная строка UI появится в Task 9 (`OverlayView.updateStatus`), здесь — `print` для проверки.

- [ ] **Step 1: VisionProcessor.process — реальная детекция**

Заменить метод `process` (типы `FaceInfo`, `FrameObservation`, extension CGRect остаются) на:

```swift
final class VisionProcessor {
    private let faceRequest = VNDetectFaceLandmarks2DRequest()
    private let handRequest = VNDetectHumanHandPoseRequest()

    init() {
        handRequest.maximumHandCount = 1
    }

    func process(_ pixelBuffer: CVPixelBuffer) -> FrameObservation {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([faceRequest, handRequest])
        let size = CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                          height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))

        return FrameObservation(face: largestFace(in: size), handPoints: handPoints(), videoSize: size)
    }

    private func largestFace(in imageSize: CGSize) -> FaceInfo? {
        guard let face = faceRequest.results?.max(by: { $0.boundingBox.area < $1.boundingBox.area }) else {
            return nil
        }
        func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let region else { return nil }
            let pts = region.pointsInImage(imageSize)
            guard !pts.isEmpty else { return nil }
            let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(pts.count) / imageSize.width,
                           y: sum.y / CGFloat(pts.count) / imageSize.height)
        }
        if let le = centroid(face.landmarks?.leftEye),
           let re = centroid(face.landmarks?.rightEye),
           let nose = centroid(face.landmarks?.nose) {
            return FaceInfo(boundingBox: face.boundingBox, leftEye: le, rightEye: re, noseTip: nose)
        }
        // Ландмарок нет — синтезируем глаза/нос из прямоугольника лица.
        let c = face.boundingBox.center
        return FaceInfo(boundingBox: face.boundingBox,
                        leftEye:  CGPoint(x: c.x - face.boundingBox.width * 0.18, y: c.y + face.boundingBox.height * 0.10),
                        rightEye: CGPoint(x: c.x + face.boundingBox.width * 0.18, y: c.y + face.boundingBox.height * 0.10),
                        noseTip:  CGPoint(x: c.x, y: c.y - face.boundingBox.height * 0.05))
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
```

- [ ] **Step 2: AppDelegate — конвейер**

```swift
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
```

- [ ] **Step 3: Сборка и все тесты**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, `Executed 17 tests, with 0 failures`.

- [ ] **Step 4: MANUAL CHECK — распознавание вживую (нужен человек у камеры)**

Пересобрать и запустить как в Task 7 Step 6 (те же команды `swift build -c release` … `open Metka.app`), затем в Terminal смотреть вывод лога — для этого запустить бинарник напрямую из бандла, чтобы лог шёл в терминал: `./Metka.app/Contents/MacOS/Metka`.

Expected:
- Лицо в кадре → в логе `лицо: да`.
- Показать 👍 и держать >0,5 с → `жест: 👍 | стабильный: 👍`.
- Убрать руку → через ~0,3 с `стабильный: —`.
- Аналогично ✌️ и 🖐. Кулак/нет руки → `жест: —`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Metka/VisionProcessor.swift Sources/Metka/AppDelegate.swift
git commit -m "feat: распознавание лица и жестов на кадре + стабилизация"
```

---

### Task 9: Оверлей: статусная строка + маска на лице

**Files:**
- Create: `Sources/Metka/ContentLoader.swift`
- Create: `Sources/Metka/OverlayView.swift`
- Modify: `Sources/Metka/AppDelegate.swift` (заменить целиком)

**Interfaces:**
- Consumes: `FrameObservation`/`FaceInfo`, `CoordinateMapper`, `ContentKind`, `HandGesture`, `CameraStatus` из предыдущих задач.
- Produces:
  - `enum ContentLoader { static var videoURL/photoURL/audioURL/maskURL: URL? }`
  - `final class OverlayView: NSView { func setContent(_ kind: ContentKind); func updateFace(_ face: FaceInfo?, mapper: CoordinateMapper); func updateStatus(raw: HandGesture?, stable: HandGesture?, faceSeen: Bool); func showCameraStatus(_ status: CameraStatus) }` — Task 9 реализует `updateFace`, `updateStatus`, `showCameraStatus` полностью; `setContent` — каркас `switch` с TODO-ветками пустыми для видео/фото/аудио НЕ допускается, поэтому видео/фото/аудио ветки реализуются прямо в Task 10 (в Task 9 `setContent` пока скрывает всё на `.idle` и печатает в консоль для остальных кейсов — Task 10 заменит ветки).

- [ ] **Step 1: ContentLoader.swift**

```swift
import Foundation

enum ContentLoader {
    private static func first(_ names: [String]) -> URL? {
        for name in names {
            let parts = name.split(separator: ".").map(String.init)
            guard parts.count == 2,
                  let url = Bundle.main.url(forResource: parts[0], withExtension: parts[1]) else { continue }
            return url
        }
        return nil
    }

    static var videoURL: URL? { first(["video.mp4", "video.mov", "video.webm"]) }
    static var photoURL: URL? { first(["photo.jpg", "photo.jpeg", "photo.png"]) }
    static var audioURL: URL? { first(["audio.mp3", "audio.wav", "audio.m4a", "audio.aiff"]) }
    static var maskURL: URL? { first(["mask.png"]) }

    static var missingDescription: String {
        var parts: [String] = []
        if videoURL == nil { parts.append("video (mp4/mov/webm)") }
        if photoURL == nil { parts.append("photo (jpg/png)") }
        if audioURL == nil { parts.append("audio (mp3/wav/m4a)") }
        if maskURL == nil { parts.append("mask.png") }
        return parts.joined(separator: ", ")
    }
}
```

- [ ] **Step 2: OverlayView.swift — статусы, подсказки, маска**

```swift
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
```

- [ ] **Step 3: AppDelegate — подключить оверлей**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let camera = CameraController()
    private var cameraView: CameraView?
    private var stabilizer = GestureStabilizer()

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
            overlay.setContent(ContentKind.from(stable))
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
```

- [ ] **Step 4: Сборка и тесты**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, `Executed 17 tests, with 0 failures`.

- [ ] **Step 5: MANUAL CHECK + КАЛИБРОВКА маски (нужен человек у камеры)**

Собрать .app как в Task 7 Step 6, но добавить в бандл ресурсы:

```bash
cd "/Users/macbookair/Documents/ОВиДР"
mkdir -p Metka.app/Contents/Resources
cp Content/mask.png Content/photo.png Content/audio.wav Content/video.mp4 Metka.app/Contents/Resources/
codesign --force --sign - Metka.app
open Metka.app
```

Expected:
- Верхний левый угол: «Жест: —», «Лицо: найдено»; низ: строка подсказок.
- Маска (очки+усы) видна, сидит на глазах, двигается вместе с лицом, слегка поворачивается с наклоном головы.
- **Калибровка:** если маска смещена — поправить `maskDropFactor` (вниз = больше) и `maskWidthFactor` (размер) в `OverlayView.init` области объявлений; если поворот «в противофазе» — заменить `rotationAngle:` на `-atan2(...)`; если отражена по горизонтали — маска нарисована асимметрично, перевернуть сам mask.png. Повторить сборку до приемлемой посадки.

- [ ] **Step 6: Commit**

```bash
git add Sources/Metka/ContentLoader.swift Sources/Metka/OverlayView.swift Sources/Metka/AppDelegate.swift
git commit -m "feat: оверлей — статусы, подсказки, маска на лице"
```

---

### Task 10: Оверлей контента — видео, фото, индикатор аудио

**Files:**
- Modify: `Sources/Metka/OverlayView.swift` (заменить `setContent`-каркас на полную реализацию + добавить слои/плееры)

**Interfaces:**
- Consumes: `ContentLoader`, `ContentKind` — всё из предыдущих задач.
- Produces: полнофункциональный `setContent(_ kind: ContentKind)`: `.video` → зацикленное видео со звуком по центру; `.photo` → фото по центру; `.audio` → играет аудио + эквалайзер-индикатор; `.idle` → всё скрыто/на паузе. Сигнатуры не меняются.

- [ ] **Step 1: Добавить в OverlayView свойства и слои**

Внутри `final class OverlayView` добавить свойства (рядом с `maskLayer`):

```swift
    private let photoLayer = CALayer()
    private var playerLayer: AVPlayerLayer?
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var audioPlayer: AVAudioPlayer?
    private var audioIndicator: CALayer?
```

В конец `init` (после `layer?.addSublayer(maskLayer)`) добавить:

```swift
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
```

- [ ] **Step 2: Полный setContent + вспомогательные методы**

Заменить каркасный `setContent(_ kind:)` на:

```swift
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
        guard let url = ContentLoader.videoURL else { return }
        if playerLayer == nil {
            let player = AVQueuePlayer()
            player.isMuted = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            let pl = AVPlayerLayer(player: player)
            pl.frame = centeredVideoRect()
            pl.cornerRadius = 14
            pl.shadowColor = NSColor.black.cgColor
            pl.shadowOpacity = 0.6
            pl.shadowRadius = 18
            layer?.addSublayer(pl)
            playerLayer = pl
            queuePlayer = player
        }
        playerLayer?.frame = centeredVideoRect()
        queuePlayer?.seek(to: .zero)
        queuePlayer?.play()
        if let pl = playerLayer { fade(pl, visible: true) }
    }

    private func stopVideo() {
        queuePlayer?.pause()
        if let pl = playerLayer { fade(pl, visible: false) }
    }

    private func startAudio() {
        if audioPlayer == nil, let url = ContentLoader.audioURL {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
        }
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.play()
        showAudioIndicator()
    }

    private func stopAudio() {
        audioPlayer?.pause()
        hideAudioIndicator()
    }

    private func centeredVideoRect() -> CGRect {
        let w: CGFloat = 480, h: w * 9 / 16
        return CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
    }

    private func showAudioIndicator() {
        if audioIndicator == nil {
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
            layer?.addSublayer(container)
            audioIndicator = container
        }
        audioIndicator?.isHidden = false
    }

    private func hideAudioIndicator() {
        audioIndicator?.isHidden = true
    }
```

Также добавить свойство `private var currentKind: ContentKind = .idle` к остальным свойствам и в `override func layout()` добавить строку:

```swift
        playerLayer?.frame = centeredVideoRect()
        audioIndicator?.frame = CGRect(x: bounds.midX - 90, y: bounds.midY - 45, width: 180, height: 90)
```

- [ ] **Step 3: Сборка и все тесты**

Run: `swift build 2>&1 | tail -3 && swift test 2>&1 | tail -3`
Expected: `Build complete!`, `Executed 17 tests, with 0 failures`.

- [ ] **Step 4: MANUAL CHECK — контент по жестам (нужен человек у камеры)**

Пересобрать с ресурсами (команды Task 9 Step 5) и `open Metka.app`.

Expected:
- 👍 держать ~0,5 с → видео появляется по центру, играет со звуком, зациклено; убрать руку → плавно исчезает, звук стоп.
- ✌️ → фото с рамкой и тенью; убрать → исчезает.
- 🖐 → играет мелодия + плашка «🔊 Аудио» с прыгающими полосками; убрать → стоп.
- Жесты переключают контент напрямую: показать ✌️ во время видео → видео исчезает, фото появляется.
- Лицо в кадре всё это время → маска продолжает висеть поверх.

- [ ] **Step 5: Commit**

```bash
git add Sources/Metka/OverlayView.swift
git commit -m "feat: контент-оверлеи — видео, фото, индикатор аудио"
```

---

### Task 11: build.sh, README, финальная сборка

**Files:**
- Create: `build.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: всё предыдущее.
- Produces: артефакт `Metka.app` одной командой `./build.sh`; документация проекта.

- [ ] **Step 1: build.sh**

```bash
#!/bin/bash
# Сборка Metka.app: бинарник + контент + Info.plist + ad-hoc подпись.
set -euo pipefail
cd "$(dirname "$0")"

APP="Metka.app"
echo "▸ swift build (release)…"
swift build -c release

echo "▸ Сборка бандла…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Metka "$APP/Contents/MacOS/Metka"

for f in video.mp4 video.mov video.webm photo.jpg photo.jpeg photo.png audio.mp3 audio.wav audio.m4a audio.aiff mask.png; do
  if [ -f "Content/$f" ]; then cp "Content/$f" "$APP/Contents/Resources/"; fi
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Метка</string>
    <key>CFBundleDisplayName</key><string>Метка</string>
    <key>CFBundleIdentifier</key><string>ru.ovdr.metka</string>
    <key>CFBundleExecutable</key><string>Metka</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSCameraUsageDescription</key>
    <string>Приложение «Метка» распознаёт лицо и жесты через камеру, чтобы показывать привязанный контент.</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▸ Подпись (ad-hoc)…"
codesign --force --sign - "$APP"

echo "✅ Готово: $APP"
echo "   Запуск: open $APP"
```

Сделать исполняемым: `chmod +x build.sh`.

- [ ] **Step 2: README.md**

```markdown
# Метка — AR-плеер по меткам (macOS)

Нативное macOS-приложение на Swift: камера + распознавание лица и жестов
(AVFoundation + Vision), контент привязан к меткам.

| Метка | Действие |
|---|---|
| Лицо в кадре | Маска-PNG накладывается на лицо (как в Snapchat) |
| 👍 большой палец вверх | Видео (со звуком, зациклено) |
| ✌️ «victory» | Фото |
| 🖐 открытая ладонь | Аудио + индикатор |

Жест нужно удержать ~0,5 с; контент живёт, пока жест в кадре.
Маска показывается, пока лицо в кадре, и не мешает остальному контенту.

## Сборка и запуск

```bash
./build.sh        # соберёт Metka.app (нужен только Swift из Command Line Tools)
open Metka.app    # при первом запуске разрешите доступ к камере
```

## Свои файлы

Положите свои файлы в `Content/` (см. Content/README.md), пересоберите `./build.sh`.
Если файлов нет — `swift Tools/GeneratePlaceholders.swift` создаст заглушки.

## Тесты

```bash
swift test   # 17 юнит-тестов чистой логики (жесты, стабилизатор, координаты)
```

## Структура

- `Sources/Metka/` — код приложения (камера, Vision, оверлеи).
- `Tools/GeneratePlaceholders.swift` — генератор демо-контента.
- `docs/superpowers/plans/` — план реализации.

## Калибровка маски

Константы `maskWidthFactor` / `maskDropFactor` в `Sources/Metka/OverlayView.swift`
задают размер и посадку маски относительно межглазного расстояния.
```

- [ ] **Step 3: Финальная сборка + полная проверка**

Run: `cd "/Users/macbookair/Documents/ОВиДР" && ./build.sh && swift test 2>&1 | tail -3`
Expected: `✅ Готово: Metka.app`, `Executed 17 tests, with 0 failures`.

MANUAL CHECK (нужен человек у камеры): `open Metka.app` и пройти чеклист:
1. Разрешение камеры выдано, видео видно, статусы «Жест/Лицо» обновляются.
2. Лицо → маска следует за лицом.
3. 👍 → видео; ✌️ → фото; 🖐 → аудио (каждое ~0,5 с удержания, исчезает при пропадании жеста).
4. Заменить любой файл в `Content/` своим → `./build.sh` → контент обновился.

- [ ] **Step 4: Commit**

```bash
git add build.sh README.md
git commit -m "feat: скрипт сборки Metka.app и README проекта"
```

---

## Self-Review (выполнен при составлении)

1. **Spec coverage:** лицо→маска (Task 8 детекция + Task 9 посадка), 👍→видео (Task 10 + ContentKind Task 4), ✌️→фото (Task 10), 🖐→аудио (Task 10), дебаунг 0,5 с (Task 3, значения 15/8 кадров), «пока жест в кадре» (Task 3 release + Task 10 setContent), по одному файлу каждого типа (Task 6 заглушки / Content пользователя, Task 11 вшивание), сборка без Xcode (Task 11 build.sh, проверена в Task 7 Step 6), русский UI (Task 9), тесты (задачи 1–5). Пропусков нет.
2. **Placeholder scan:** шагов «сделать потом» нет; единственные осознанные точки настройки — константы калибровки маски в Task 9 Step 5 с явной инструкцией.
3. **Type consistency:** `HandGesture`, `GestureStabilizer.feed -> HandGesture?`, `ContentKind.from(HandGesture?)`, `CoordinateMapper(videoSize:layerSize:)`, `FrameObservation(face:handPoints:videoSize:)`, `OverlayView.setContent/updateFace/updateStatus/showCameraStatus`, `ContentLoader.*URL` — имена сверены между задачами.
