import SwiftUI
import AppKit

@main
struct PrismaticApp: App {
    @State private var controller = LEDController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
        } label: {
            Image(nsImage: Self.menuBarIcon)
                .opacity(controller.status == .connected ? 1.0 : 0.45)
        }
        .menuBarExtraStyle(.window)
    }

    /// SteelSeries logo resized to menu-bar size and marked as a template image
    /// (MenuBarExtra ignores SwiftUI `.frame()` on its label image, so we size the
    /// underlying NSImage directly).
    private static let menuBarIcon: NSImage = {
        let height: CGFloat = 18
        guard let base = NSImage(named: "steelseries-logo") else {
            return NSImage(systemSymbolName: "hifispeaker.fill", accessibilityDescription: "Prismatic") ?? NSImage()
        }
        let aspect = base.size.width > 0 ? base.size.width / base.size.height : 1
        let icon = (base.copy() as? NSImage) ?? base
        icon.size = NSSize(width: height * aspect, height: height)
        icon.isTemplate = true
        return icon
    }()
}
