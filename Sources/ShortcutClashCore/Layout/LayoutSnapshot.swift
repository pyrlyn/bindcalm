import Foundation

/// Character tables of the enabled keyboard layouts, captured on the main thread
/// (Text Input Sources asserts the main queue on recent macOS) and then shared freely.
public struct LayoutSnapshot: Sendable, Codable, Hashable {
    public struct Layout: Sendable, Codable, Hashable, Identifiable {
        public var id: String
        public var name: String
        public var isCurrent: Bool
        public var isASCIICapable: Bool
        public var unshifted: [UInt16: String]
        public var shifted: [UInt16: String]

        public init(id: String, name: String, isCurrent: Bool, isASCIICapable: Bool,
                    unshifted: [UInt16: String], shifted: [UInt16: String]) {
            self.id = id
            self.name = name
            self.isCurrent = isCurrent
            self.isASCIICapable = isASCIICapable
            self.unshifted = unshifted
            self.shifted = shifted
        }

        public func keyCode(for character: String) -> (keyCode: UInt16, shift: Bool)? {
            let needle = character.lowercased()
            if let hit = unshifted.first(where: { $0.value.lowercased() == needle }) { return (hit.key, false) }
            if let hit = shifted.first(where: { $0.value == character }) { return (hit.key, true) }
            return nil
        }
    }

    public var layouts: [Layout]
    /// "Automatically switch to a document's input source" (per-window/per-app input source).
    public var perDocumentInputSource: Bool?

    public init(layouts: [Layout] = [], perDocumentInputSource: Bool? = nil) {
        self.layouts = layouts
        self.perDocumentInputSource = perDocumentInputSource
    }

    public static let empty = LayoutSnapshot()

    public func keyCode(for character: String) -> (keyCode: UInt16, shift: Bool)? {
        for layout in layouts.sorted(by: { $0.isCurrent && !$1.isCurrent }) {
            if let hit = layout.keyCode(for: character) { return hit }
        }
        return nil
    }
}
