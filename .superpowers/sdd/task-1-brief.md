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

