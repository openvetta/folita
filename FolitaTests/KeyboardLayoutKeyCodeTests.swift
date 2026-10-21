import Carbon.HIToolbox
import Testing
@testable import Folita

struct KeyboardLayoutKeyCodeTests {
    /// 当前机器的布局里一定能找到产生 v 的键；用不会出现在真实键位里的兜底值区分「查到」与「退回兜底」。
    @Test func findsTheKeyThatProducesV() {
        let sentinel: CGKeyCode = 999
        let code = KeyboardLayoutKeyCode.keyCode(producing: "v", fallback: sentinel)
        #expect(code != sentinel)
        #expect(code < 128)
    }

    /// 字符不在任何键位上时退回兜底，而不是随便给一个键。
    @Test func fallsBackWhenNoKeyProducesTheCharacter() {
        #expect(KeyboardLayoutKeyCode.keyCode(producing: "€", fallback: 42) == 42)
    }
}
