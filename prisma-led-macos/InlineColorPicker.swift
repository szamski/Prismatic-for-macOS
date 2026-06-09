import SwiftUI
import AppKit

/// A self-contained color picker (saturation/brightness field + hue slider) drawn
/// entirely in SwiftUI. Needed because `ColorPicker` / `NSColorWell` / `NSColorPanel`
/// don't present from a `MenuBarExtra` window in an accessory (LSUIElement) app.
struct InlineColorPicker: View {
    @Binding var color: Color

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    init(color: Binding<Color>) {
        _color = color
        let hsb = color.wrappedValue.hsbComponents
        _hue = State(initialValue: hsb.hue)
        _saturation = State(initialValue: hsb.saturation)
        _brightness = State(initialValue: hsb.brightness)
    }

    var body: some View {
        VStack(spacing: 10) {
            saturationBrightnessField
            hueSlider
        }
        .onChange(of: color) { _, newValue in
            syncFromBinding(newValue)
        }
    }

    // MARK: - Saturation / Brightness field

    private var saturationBrightnessField: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(hue: hue, saturation: 1, brightness: 1))
                LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                thumb
                    .position(
                        x: saturation * geo.size.width,
                        y: (1 - brightness) * geo.size.height
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    saturation = clamp(value.location.x / geo.size.width)
                    brightness = clamp(1 - value.location.y / geo.size.height)
                    pushColor()
                }
            )
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.12)))
    }

    // MARK: - Hue slider

    private var hueSlider: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(colors: hueStops, startPoint: .leading, endPoint: .trailing)
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .background(Circle().fill(Color(hue: hue, saturation: 1, brightness: 1)))
                    .frame(width: 18, height: 18)
                    .shadow(radius: 1)
                    .position(x: hue * geo.size.width, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    hue = clamp(value.location.x / geo.size.width)
                    pushColor()
                }
            )
        }
        .frame(height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var thumb: some View {
        Circle()
            .strokeBorder(.white, lineWidth: 2)
            .background(Circle().fill(currentColor))
            .frame(width: 16, height: 16)
            .shadow(radius: 1)
    }

    // MARK: - Helpers

    private var currentColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private var hueStops: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 6.0).map { Color(hue: $0, saturation: 1, brightness: 1) }
    }

    private func pushColor() { color = currentColor }

    private func clamp(_ value: CGFloat) -> Double { Double(max(0, min(1, value))) }

    private func syncFromBinding(_ newValue: Color) {
        let hsb = newValue.hsbComponents
        // Avoid clobbering our state when the change came from our own edit.
        guard abs(hsb.hue - hue) > 0.001
            || abs(hsb.saturation - saturation) > 0.001
            || abs(hsb.brightness - brightness) > 0.001
        else { return }
        // Hue is undefined for grays; keep ours so the slider doesn't jump to red.
        if hsb.saturation > 0.001 { hue = hsb.hue }
        saturation = hsb.saturation
        brightness = hsb.brightness
    }
}

extension Color {
    var hsbComponents: (hue: Double, saturation: Double, brightness: Double) {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        return (Double(ns.hueComponent), Double(ns.saturationComponent), Double(ns.brightnessComponent))
    }
}
