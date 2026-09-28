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
