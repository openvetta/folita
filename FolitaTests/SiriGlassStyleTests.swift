import AppKit
import SwiftUI
import Testing
@testable import Folita

struct SiriGlassStyleTests {
    @Test func darkAndLightResolveToDistinctStyles() {
        #expect(SiriGlassStyle.resolve(for: .dark) != SiriGlassStyle.resolve(for: .light))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func tintFadesOutTowardsBottom(colorScheme: ColorScheme) {
        let tint = SiriGlassStyle.resolve(for: colorScheme).tint

        #expect(tint.first?.location == 0)
        #expect(tint.last?.location == 1)
        #expect(tint.map(\.location) == tint.map(\.location).sorted())
    }

    /// 选中行底色近乎实心，落在容器下部的渐隐区时也不会透出桌面。
    @Test(arguments: [ColorScheme.dark, .light])
    func selectionFillIsNearlyOpaque(colorScheme: ColorScheme) {
        let selection = NSColor(SiriGlassStyle.resolve(for: colorScheme).selection)

        #expect(selection.alphaComponent >= 0.9)
    }

    /// 图标底色是不透明的实心块，且与选中行底色不同：选中时图标也要看得清。
    @Test(arguments: [ColorScheme.dark, .light])
    func iconChipIsSolidAndDistinctFromSelection(colorScheme: ColorScheme) {
        let style = SiriGlassStyle.resolve(for: colorScheme)

        #expect(NSColor(style.iconBackground).alphaComponent >= 0.99)
        #expect(NSColor(style.iconForeground).alphaComponent >= 0.99)
        #expect(style.iconBackground != style.selection)
    }

    /// 分栏只靠一条细线：看得见但不抢眼，不能比选中行的描边更重。
    @Test(arguments: [ColorScheme.dark, .light])
    func peekDividerIsSubtle(colorScheme: ColorScheme) {
        let style = SiriGlassStyle.resolve(for: colorScheme)
        let alpha = NSColor(style.peekDivider).alphaComponent

        #expect(alpha > 0.05)
        #expect(alpha <= 0.15)
    }
}
