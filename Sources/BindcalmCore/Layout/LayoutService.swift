import Carbon
import Foundation

/// Reads enabled keyboard layouts through Text Input Sources and translates key codes with UCKeyTranslate.
@MainActor
public enum LayoutService {
    public static func snapshot() -> LayoutSnapshot {
        let currentID = currentLayoutID()
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable: true,
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return LayoutSnapshot(layouts: [], perDocumentInputSource: perDocumentInputSourceEnabled())
        }
        var layouts: [LayoutSnapshot.Layout] = []
        for source in list {
            guard let type: String = property(source, kTISPropertyInputSourceType),
                  type == (kTISTypeKeyboardLayout as String) else { continue }
            guard let layout = makeLayout(source, currentID: currentID) else { continue }
            if !layouts.contains(where: { $0.id == layout.id }) { layouts.append(layout) }
        }
        return LayoutSnapshot(layouts: layouts, perDocumentInputSource: perDocumentInputSourceEnabled())
    }

    public static func currentInputSourceName() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return property(source, kTISPropertyLocalizedName)
    }

    static func currentLayoutID() -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return property(source, kTISPropertyInputSourceID)
    }

    static func makeLayout(_ source: TISInputSource, currentID: String?) -> LayoutSnapshot.Layout? {
        guard let id: String = property(source, kTISPropertyInputSourceID),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        let name: String = property(source, kTISPropertyLocalizedName) ?? id
        let ascii = (property(source, kTISPropertyInputSourceIsASCIICapable) as Bool?) ?? false
        var unshifted: [UInt16: String] = [:]
        var shifted: [UInt16: String] = [:]
        for code in KeyCodes.printableKeyCodes {
            if let char = translate(code, shift: false, layoutData: data) { unshifted[code] = char }
            if let char = translate(code, shift: true, layoutData: data) { shifted[code] = char }
        }
        return LayoutSnapshot.Layout(id: id, name: name, isCurrent: id == currentID, isASCIICapable: ascii,
                                     unshifted: unshifted, shifted: shifted)
    }

    public static func translate(_ keyCode: UInt16, shift: Bool, layoutData: CFData) -> String? {
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }
        return bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout -> String? in
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let modifierState: UInt32 = shift ? UInt32((shiftKey >> 8) & 0xFF) : 0
            let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), modifierState,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                        &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            let text = String(utf16CodeUnits: chars, count: length)
            return text.trimmingCharacters(in: .controlCharacters).isEmpty ? nil : text
        }
    }

    private static func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        let object = Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
        if T.self == Bool.self, let number = object as? NSNumber { return number.boolValue as? T }
        return object as? T
    }

    /// System Settings → Keyboard → Input Sources → "Automatically switch to a document's input source".
    static func perDocumentInputSourceEnabled() -> Bool? {
        guard let props = CFPreferencesCopyAppValue("AppleGlobalTextInputProperties" as CFString,
                                                    "com.apple.HIToolbox" as CFString) as? [String: Any] else { return nil }
        return (props["TextInputGlobalPropertyPerContextInput"] as? NSNumber)?.boolValue
    }
}
