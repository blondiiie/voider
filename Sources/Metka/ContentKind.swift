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
