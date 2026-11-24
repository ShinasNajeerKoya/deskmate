import AppKit
import CryptoKit
import Foundation

/// Album artwork for the phone (which has no internet): the Mac downloads each image
/// once, shrinks it to a small JPEG and keeps it by a short id derived from its URL.
/// Images are also saved on disk for a day, so a restart doesn't download them again;
/// anything older than a day is deleted and fetched fresh.
final class ArtCache {
    private static let maxAge: TimeInterval = 24 * 60 * 60
    private let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/Deskmate/art")

    init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where Self.isOld(file) { try? FileManager.default.removeItem(at: file) }
    }

    private static func isOld(_ file: URL) -> Bool {
        let saved = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return Date().timeIntervalSince(saved) > maxAge
    }

    /// Called on the main thread when an image is ready to send.
    var onReady: ((_ id: String) -> Void)?
    private var images: [String: Data] = [:]
    private var loading: Set<String> = []
    private var order: [String] = []

    /// The id for `url` at `size` px; starts the download if needed. Empty URL → nil.
    func id(for url: String, size: Int) -> String? {
        guard !url.isEmpty, let source = URL(string: url) else { return nil }
        let id = Self.id(url, size)
        if images[id] == nil {
            let file = folder.appendingPathComponent("\(id).jpg")
            if !Self.isOld(file), let saved = try? Data(contentsOf: file) {
                images[id] = saved
                remember(id)
            }
        }
        if images[id] == nil && !loading.contains(id) {
            loading.insert(id)
            URLSession.shared.dataTask(with: source) { [weak self] data, _, _ in
                let jpeg = data.flatMap { Self.shrink($0, to: size) }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.loading.remove(id)
                    guard let jpeg else { return }
                    self.images[id] = jpeg
                    try? jpeg.write(to: self.folder.appendingPathComponent("\(id).jpg"), options: .atomic)
                    self.remember(id)
                    self.onReady?(id)
                }
            }.resume()
        }
        return id
    }

    func data(for id: String) -> Data? { images[id] }

    /// Keeps memory small: the oldest images drop out of memory (they stay on disk).
    private func remember(_ id: String) {
        order.append(id)
        if order.count > 60, let old = order.first {
            order.removeFirst()
            images[old] = nil
        }
    }

    private static func id(_ url: String, _ size: Int) -> String {
        let digest = SHA256.hash(data: Data("\(size)|\(url)".utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Square-cropped, `size`×`size` JPEG.
    private static func shrink(_ data: Data, to size: Int) -> Data? {
        guard let image = NSImage(data: data), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let side = min(cg.width, cg.height)
        let crop = CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)
        guard let square = cg.cropping(to: crop),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(square, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let scaled = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled).representation(using: .jpeg, properties: [.compressionFactor: 0.78])
    }
}
