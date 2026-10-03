import Foundation

/// Layout-aware checks. Global hotkeys (Carbon, symbolic) match key codes, while menu key equivalents
/// are declared as characters; with several layouts enabled the same character can sit on another key.
public enum LayoutAnalyzer {
    public static func characters(for keyCode: UInt16, in snapshot: LayoutSnapshot) -> [(layout: String, character: String)] {
        snapshot.layouts.map { ($0.name, $0.unshifted[keyCode] ?? "—") }
    }

    /// Combos a character-defined claim would occupy in other ASCII-capable layouts
    /// (Cocoa resolves Command shortcuts through the ASCII-capable layout when the current one is not).
    public static func alternateCombos(for finding: DiscoveredHotKey, in snapshot: LayoutSnapshot) -> [(layout: String, combo: KeyCombo)] {
        guard let char = finding.definingCharacter, char.count == 1,
              char.unicodeScalars.first.map({ $0.value < 0xF700 }) == true else { return [] }
        var result: [(String, KeyCombo)] = []
        for layout in snapshot.layouts where layout.isASCIICapable {
            guard let hit = layout.keyCode(for: char), hit.keyCode != finding.combo.keyCode else { continue }
            var mods = finding.combo.modifiers
            if hit.shift { mods.insert(.shift) }
            result.append((layout.name, KeyCombo(keyCode: hit.keyCode, modifiers: mods)))
        }
        return result
    }

    public static func annotate(_ groups: [HotKeyGroup], layouts: LayoutSnapshot) -> [HotKeyGroup] {
        guard !layouts.layouts.isEmpty else { return groups }
        let byCombo = Dictionary(uniqueKeysWithValues: groups.map { ($0.combo, $0) })
        let nonASCII = layouts.layouts.filter { !$0.isASCIICapable }

        return groups.map { group in
            var group = group
            var notes: [LayoutNote] = []
            for finding in group.findings where finding.enabled && finding.scope == .inApp {
                for alt in alternateCombos(for: finding, in: layouts) {
                    guard let other = byCombo[alt.combo] else { continue }
                    let rivals = other.findings.filter { $0.enabled && $0.scope == .global && $0.owner.key != finding.owner.key }
                    guard let rival = rivals.first else { continue }
                    notes.append(LayoutNote(
                        layoutName: alt.layout,
                        message: "В раскладке «\(alt.layout)» символ «\(finding.definingCharacter ?? "")» (\(finding.owner.name)) "
                            + "находится на клавише \(alt.combo.display) — она занята: \(rival.owner.name)",
                        isConflict: true))
                }
            }
            if group.findings.contains(where: { $0.definingCharacter != nil }) {
                for layout in nonASCII {
                    let produced = layout.unshifted[group.combo.keyCode] ?? "—"
                    notes.append(LayoutNote(
                        layoutName: layout.name,
                        message: "В раскладке «\(layout.name)» эта клавиша даёт «\(produced)». Приложения, сравнивающие "
                            + "символ вместо кода клавиши, могут не сработать или сработать иначе.",
                        isConflict: false))
                }
            }
            var unique: [LayoutNote] = []
            for note in notes where !unique.contains(note) { unique.append(note) }
            group.layoutNotes = unique
            if group.status == .none || group.status == .inAppDuplicate, unique.contains(where: { $0.isConflict }) {
                group.status = .layoutConflict
            }
            return group
        }
    }
}
