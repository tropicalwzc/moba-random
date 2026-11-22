import UIKit
import ImageIO

struct Bo3AvatarDescriptor: Equatable, Sendable {
    let displayName: String
    let officialName: String?
    let file: String?
    let element: String?
    let fallbackSeed: UInt32

    var hasImage: Bool {
        file != nil
    }
}

@MainActor
final class Bo3AvatarCatalog {
    static let shared = Bo3AvatarCatalog()

    private struct Entry: Decodable {
        let file: String
        let element: String
    }

    private struct Index: Decodable {
        let version: Int
        let aliases: [String: String]
        let avatars: [String: Entry]
    }

    private let bundle: Bundle
    private let aliases: [String: String]
    private let avatars: [String: Entry]
    private let cache = NSCache<NSString, UIImage>()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        guard let url = bundle.url(
            forResource: "avatar-index",
            withExtension: "json",
            subdirectory: "BO3"
        ),
        let data = try? Data(contentsOf: url),
        let index = try? JSONDecoder().decode(Index.self, from: data) else {
            aliases = [:]
            avatars = [:]
            cache.countLimit = 200
            return
        }
        aliases = index.aliases
        avatars = index.avatars
        cache.countLimit = 200
    }

    var avatarCount: Int {
        avatars.count
    }

    var aliasCount: Int {
        aliases.count
    }

    func descriptor(for name: String) -> Bo3AvatarDescriptor {
        let display = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let official = aliases[display] ?? display
        let entry = avatars[official]
        return Bo3AvatarDescriptor(
            displayName: display.isEmpty ? "?" : display,
            officialName: entry == nil ? nil : official,
            file: entry?.file,
            element: entry?.element,
            fallbackSeed: Bo3Palette.hash(display)
        )
    }

    func image(for descriptor: Bo3AvatarDescriptor) -> UIImage? {
        guard let file = descriptor.file else { return nil }
        let key = file as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = bundle.url(
            forResource: file,
            withExtension: "webp",
            subdirectory: "BO3/avatars"
        ) else {
            return nil
        }
        let image = UIImage(contentsOfFile: url.path) ?? decodedImage(at: url)
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    func image(named name: String) -> UIImage? {
        image(for: descriptor(for: name))
    }

    private func decodedImage(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
