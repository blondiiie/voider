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
