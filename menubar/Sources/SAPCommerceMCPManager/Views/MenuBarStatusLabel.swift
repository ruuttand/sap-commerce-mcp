import SwiftUI
import AppKit

struct MenuBarStatusLabel: View {
    @ObservedObject var indexService: IndexService
    @ObservedObject var serverManager: ServerProcessManager
    @State private var pulseOn = false

    var body: some View {
        Image(nsImage: currentImage)
            .onAppear { startPulse() }
            .onChange(of: indexService.isRebuilding) { _ in startPulse() }
    }

    private var currentImage: NSImage {
        if indexService.isRebuilding {
            return makeImage(color: NSColor.systemYellow.withAlphaComponent(pulseOn ? 1.0 : 0.25))
        } else if serverManager.state.isRunning {
            return makeImage(color: .systemGreen)
        } else {
            return makeImage(color: .systemRed)
        }
    }

    private func startPulse() {
        guard indexService.isRebuilding else { return }
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            pulseOn = true
        }
    }

    private func makeImage(color: NSColor) -> NSImage {
        let iconSize: CGFloat = 16
        let dotSize: CGFloat = 7
        let spacing: CGFloat = 3
        let totalWidth = iconSize + spacing + dotSize
        let height = iconSize

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
            let symbolConfig = NSImage.SymbolConfiguration(scale: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
            if let symbol = NSImage(systemSymbolName: "magnifyingglass",
                                    accessibilityDescription: nil)?
                .withSymbolConfiguration(symbolConfig) {
                NSGraphicsContext.current?.imageInterpolation = .high
                symbol.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize))
            }

            // Draw the colored status dot
            color.setFill()
            let dotX = iconSize + spacing
            let dotY = (height - dotSize) / 2
            NSBezierPath(ovalIn: NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize)).fill()

            return true
        }

        // NOT a template — preserves the dot color
        image.isTemplate = false
        return image
    }
}
