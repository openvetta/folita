import CoreGraphics
import Foundation
import Testing
@testable import Folita

@MainActor
struct PanelPlacementTests {
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
    private let inset = ClipboardPanelMetrics.shadowInset

    @Test func topCenterKeepsExistingFrame() {
        let frame = ClipboardPanelMetrics.windowFrame(placement: .topCenter, in: visible, cursor: CGPoint(x: 10, y: 10))
        #expect(frame == ClipboardPanelMetrics.windowFrame(in: visible))
    }

    @Test func centerPlacesContainerAtMiddleOfVisibleArea() {
        let frame = ClipboardPanelMetrics.windowFrame(placement: .center, in: visible, cursor: .zero)
        #expect(frame.size == ClipboardPanelMetrics.windowSize)
        #expect(abs(frame.midX - visible.midX) <= 1)
        #expect(abs(frame.midY - visible.midY) <= 1)
    }

    @Test func cursorAnchorsContainerTopLeftAtPointer() {
        let cursor = CGPoint(x: 600, y: 700)
        let frame = ClipboardPanelMetrics.windowFrame(placement: .cursor, in: visible, cursor: cursor)
        let container = frame.insetBy(dx: inset, dy: inset)

        #expect(container.minX == cursor.x)
        #expect(container.maxY == cursor.y + ClipboardPanelMetrics.cursorOffset)
        #expect(container.contains(cursor))
    }

    @Test func cursorNearBottomRightCornerShiftsPanelInsideScreen() {
        let frame = ClipboardPanelMetrics.windowFrame(placement: .cursor, in: visible, cursor: CGPoint(x: 1500, y: 20))
        let container = frame.insetBy(dx: inset, dy: inset)

        #expect(container.maxX == visible.maxX)
        #expect(container.minY == visible.minY)
    }

    @Test func cursorNearTopLeftCornerShiftsPanelInsideScreen() {
        let frame = ClipboardPanelMetrics.windowFrame(placement: .cursor, in: visible, cursor: CGPoint(x: -5, y: 950))
        let container = frame.insetBy(dx: inset, dy: inset)

        #expect(container.minX == visible.minX)
        #expect(container.maxY == visible.maxY)
    }

    @Test func cursorOnSecondaryScreenStaysInsideThatScreen() {
        let secondary = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
        let frame = ClipboardPanelMetrics.windowFrame(placement: .cursor, in: secondary, cursor: CGPoint(x: 3400, y: 300))
        let container = frame.insetBy(dx: inset, dy: inset)

        #expect(container.maxX == secondary.maxX)
        #expect(secondary.contains(container.origin))
    }

    @Test func settingsDefaultToTopCenterAndPersist() {
        let suite = "FolitaTests.Placement.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = PanelPlacementSettings(userDefaults: defaults)
        #expect(settings.placement == .topCenter)

        settings.placement = .cursor
        #expect(PanelPlacementSettings(userDefaults: defaults).placement == .cursor)
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        let suite = "FolitaTests.Placement.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("elsewhere", forKey: PanelPlacementSettings.placementKey)

        #expect(PanelPlacementSettings(userDefaults: defaults).placement == .topCenter)
    }
}
