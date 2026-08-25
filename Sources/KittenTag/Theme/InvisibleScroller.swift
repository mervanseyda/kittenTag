import AppKit

/// Keeps scrolling fully functional while preventing macOS' legacy scrollbars
/// from reserving space or drawing over kittenTag's content.
final class InvisibleScroller: NSScroller {
    override class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        0
    }

    override func draw(_ dirtyRect: NSRect) {}
    override func drawKnob() {}
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
}

@MainActor
enum ScrollbarAppearance {
    static func hide(in scrollView: NSScrollView, vertical: Bool = true) {
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScroller = InvisibleScroller(frame: .zero)

        if vertical {
            if !(scrollView.verticalScroller is InvisibleScroller) {
                scrollView.verticalScroller = InvisibleScroller(frame: .zero)
            }
            scrollView.hasVerticalScroller = true
        } else {
            scrollView.hasVerticalScroller = false
        }
    }
}
