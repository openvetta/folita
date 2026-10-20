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
}
