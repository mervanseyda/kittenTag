import SwiftUI
import AppKit

extension Color {
    // Brand solid colors
    static let brandWalnut = Color(red: 0.443, green: 0.251, blue: 0.122)      // #71401F
    static let brandHoney = Color(red: 0.843, green: 0.604, blue: 0.220)       // #D79A38
    static let brandAmber = Color(red: 0.616, green: 0.341, blue: 0.161)       // #9D5729
    static let brandOlive = Color(red: 0.604, green: 0.627, blue: 0.502)       // #9AA080
    static let brandPaper = Color(red: 0.965, green: 0.941, blue: 0.894)       // #F6F0E4
    static let brandPaperDeep = Color(red: 0.933, green: 0.894, blue: 0.824)   // #EEE4D2
    static let brandWarmWhite = Color(red: 1.000, green: 0.992, blue: 0.973)   // #FFFDF8
    static let brandInk = Color(red: 0.141, green: 0.137, blue: 0.122)         // #24231F
    static let brandStone = Color(red: 0.439, green: 0.420, blue: 0.380)       // #706B61
    static let brandLine = Color(red: 0.855, green: 0.804, blue: 0.725)        // #DACDB9
    static let brandSelection = Color(red: 0.965, green: 0.898, blue: 0.765)   // #F6E5C3
    static var brandRail: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.165, green: 0.141, blue: 0.110, alpha: 1) // #2A241C
                : NSColor(red: 0.945, green: 0.933, blue: 0.910, alpha: 1) // #F1EEE8
        })
    }

    static var brandRailForeground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.725, green: 0.678, blue: 0.596, alpha: 1) // #B9AD98
                : NSColor(red: 0.443, green: 0.420, blue: 0.384, alpha: 1) // #716B62
        })
    }

    static var ktSecondaryText: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.690, green: 0.675, blue: 0.645, alpha: 1)
                : NSColor.secondaryLabelColor
        })
    }

    static var brandRailSelection: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.616, green: 0.341, blue: 0.161, alpha: 0.18)
                : NSColor(red: 0.918, green: 0.847, blue: 0.718, alpha: 1) // #EAD8B7
        })
    }

    static var brandRailHover: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.227, green: 0.196, blue: 0.149, alpha: 1) // #3A3226
                : NSColor(red: 0.910, green: 0.886, blue: 0.847, alpha: 1) // #E8E2D8
        })
    }

    static var brandRailHoverForeground: Color { brandRailActive }
    static var brandRailSelectionForeground: Color { brandRailActive }
    static var brandRailActive: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.843, green: 0.604, blue: 0.220, alpha: 1) // #D79A38
                : NSColor(red: 0.588, green: 0.357, blue: 0.118, alpha: 1) // #965B1E
        })
    }
    static var brandRailDivider: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.227, green: 0.196, blue: 0.149, alpha: 1)
                : NSColor(red: 0.867, green: 0.851, blue: 0.824, alpha: 1) // #DDD9D2
        })
    }

    static let brandSelectionText = Color(red: 0.443, green: 0.251, blue: 0.122) // #71401F
    static var brandPrimaryAction: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.843, green: 0.604, blue: 0.220, alpha: 1)
                : NSColor(red: 0.482, green: 0.263, blue: 0.106, alpha: 1) // #7B431B
        })
    }
    
    // Dynamic brand tint color: Walnut in light mode, Honey in dark mode
    static var brandTint: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.843, green: 0.604, blue: 0.220, alpha: 1.0) // Honey #D79A38
            } else {
                return NSColor(red: 0.443, green: 0.251, blue: 0.122, alpha: 1.0) // Walnut #71401F
            }
        })
    }
    
    // Dynamic background for inspector
    static var brandInspectorBg: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor.windowBackgroundColor
            } else {
                return NSColor(red: 0.969, green: 0.965, blue: 0.953, alpha: 1.0) // Inspector #F7F6F3
            }
        })
    }

    static var brandWelcomePanel: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.115, green: 0.102, blue: 0.086, alpha: 1)
                : NSColor(red: 0.965, green: 0.941, blue: 0.894, alpha: 1)
        })
    }

    static var brandWelcomeInk: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.965, green: 0.941, blue: 0.894, alpha: 1)
                : NSColor(red: 0.141, green: 0.137, blue: 0.122, alpha: 1)
        })
    }

    static var brandWelcomeMuted: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.805, green: 0.770, blue: 0.710, alpha: 1)
                : NSColor(red: 0.335, green: 0.318, blue: 0.286, alpha: 1)
        })
    }

    static var ktCanvas: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.105, green: 0.105, blue: 0.110, alpha: 1)
                : NSColor.white
        })
    }

    static var ktSidebar: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.125, green: 0.125, blue: 0.132, alpha: 1)
                : NSColor(red: 0.956, green: 0.956, blue: 0.962, alpha: 1)
        })
    }

    static var ktControl: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.175, green: 0.175, blue: 0.185, alpha: 1)
                : NSColor.white
        })
    }

    static var ktBorder: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.11)
                : NSColor(red: 0.882, green: 0.871, blue: 0.847, alpha: 1) // #E1DED8
        })
    }

    static var ktSubtleFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.055)
                : NSColor.black.withAlphaComponent(0.035)
        })
    }
}

enum KTLayout {
    static let navigationRailWidth: CGFloat = 76
    static let sidebarWidth: CGFloat = 380
    static let headerHeight: CGFloat = 46
    static let controlHeight: CGFloat = 32
    static let radius: CGFloat = 8
    static let pagePadding: CGFloat = 16
}

struct KTInitialFocusClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusClearingView {
        FocusClearingView(frame: .zero)
    }

    func updateNSView(_ nsView: FocusClearingView, context: Context) {}

    final class FocusClearingView: NSView {
        private var hasClearedInitialFocus = false

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !hasClearedInitialFocus, window != nil else { return }
            hasClearedInitialFocus = true
            window?.initialFirstResponder = self
            window?.makeFirstResponder(self)
        }
    }
}

struct KTControlSurface: View {
    var emphasized = false
    var focused = false

    var body: some View {
        RoundedRectangle(cornerRadius: KTLayout.radius, style: .continuous)
            .fill(emphasized ? Color.brandPrimaryAction : Color.ktControl)
            .overlay {
                RoundedRectangle(cornerRadius: KTLayout.radius, style: .continuous)
                    .stroke(
                        focused ? Color.brandHoney.opacity(0.88) : (emphasized ? Color.clear : Color.ktBorder),
                        lineWidth: focused ? 1.5 : 1
                    )
            }
            .shadow(
                color: focused ? Color.brandHoney.opacity(0.16) : .black.opacity(emphasized ? 0.08 : 0.035),
                radius: focused ? 2 : 1,
                y: focused ? 0 : 1
            )
    }
}

struct KTButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var compact = false
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 7 : 11)
            .frame(minWidth: compact ? KTLayout.controlHeight : nil, minHeight: KTLayout.controlHeight)
            .background {
                if prominent && !isEnabled {
                    RoundedRectangle(cornerRadius: KTLayout.radius, style: .continuous)
                        .fill(Color.brandTint.opacity(0.11))
                        .overlay {
                            RoundedRectangle(cornerRadius: KTLayout.radius, style: .continuous)
                                .stroke(Color.brandTint.opacity(0.10), lineWidth: 1)
                        }
                } else {
                    KTControlSurface(emphasized: prominent)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: KTLayout.radius, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.68 : 1) : (prominent ? 1 : 0.38))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }

    private var foregroundColor: Color {
        if prominent {
            return isEnabled ? .white : Color.brandTint.opacity(0.40)
        }
        return .primary
    }
}

struct KTFieldSurface: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(KTControlSurface(focused: isFocused))
    }
}

extension View {
    func ktFieldSurface(isFocused: Bool = false) -> some View {
        modifier(KTFieldSurface(isFocused: isFocused))
    }
}
