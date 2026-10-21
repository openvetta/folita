import Carbon.HIToolbox
import Foundation

/// 在当前键盘布局里找出产生某个字符的物理键位。
/// 发送 ⌘V 要用「产生 v 的那个键」：Dvorak 等布局下 ANSI 的 9 号键不是 V；
/// 另一方面不能往事件里写入字符串去补救，Electron 等应用对这种事件不响应快捷键。
enum KeyboardLayoutKeyCode {
    /// ANSI 键盘上 V 的键位，布局读不到时的兜底。
    static let ansiV: CGKeyCode = 9

    /// 当前输入法是中文等非拉丁布局时，退回到可输入 ASCII 的布局来查找。
    static func keyCode(producing character: Character, fallback: CGKeyCode = ansiV) -> CGKeyCode {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return fallback }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let keyboardType = UInt32(LMGetKbdType())

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return fallback }
            for code in 0..<UInt16(128) {
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, code, UInt16(kUCKeyActionDown), 0, keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters
                )
                if status == noErr, length == 1, String(utf16CodeUnits: characters, count: length) == String(character) {
                    return code
                }
            }
            return fallback
        }
    }
}
