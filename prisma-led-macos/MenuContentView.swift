import SwiftUI

struct MenuContentView: View {
    @Bindable var controller: LEDController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            titleBar
            
            sectionDivider

            if controller.status == .disconnected {
                connectionBanner
            }
            

            brightnessControl

            sectionDivider

            colorsSection

            sectionDivider

            footer
        }
        .padding(10)
        .frame(width: 300)
    }

    /// Full-width separator that runs edge-to-edge like a native menu.
    private var sectionDivider: some View {
        Divider().padding(.horizontal, -16)
    }

    // MARK: - Title

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prismatic for macOS")
                .font(.system(size: 12).bold())
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.bottom, 3)

            HStack(spacing: 10) {
                Image("arena7")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 55)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arena 7")
                        .font(.headline)
                    statusLabel
                }
                Spacer()
                Toggle("", isOn: $controller.isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help(controller.isOn ? "Turn lighting off" : "Turn lighting on")
            }
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        }
    }

    private var statusText: String {
        switch controller.status {
        case .connected: return "Connected"
        case .connecting: return "Searching…"
        case .disconnected: return "Not found"
        }
    }

    private var connectionBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(controller.statusMessage ?? "Arena 7 not found. Connect the speakers via USB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Reconnect") { controller.reconnect() }
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Brightness

    @State private var isDraggingBrightness = false

    private var brightnessControl: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "sun.min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                brightnessSlider
                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!controller.isOn)
        .opacity(controller.isOn ? 1 : 0.5)
    }

    private var brightnessSlider: some View {
        Slider(value: $controller.brightness, in: 0...1) { editing in
            isDraggingBrightness = editing
        }
        .overlay(alignment: .top) {
            if isDraggingBrightness {
                GeometryReader { geo in
                    // Thumb center travels across the track minus the thumb width.
                    let thumbWidth: CGFloat = 20
                    let usableWidth = geo.size.width - thumbWidth
                    let thumbX = thumbWidth / 2 + usableWidth * controller.brightness
                    let percent = Int((controller.brightness * 100).rounded())

                    Text("\(percent)%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .fixedSize()
                        .position(x: thumbX, y: -14)
                }
            }
        }
    }

    // MARK: - Colors

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Customize LED lighting colors")
                .font(.system(size: 12).bold())
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.top, 6)
                .padding(.bottom, 3)

            HStack(spacing: 8) {
                Text("Select active device:")
                    .font(.body)
                Spacer()
                Picker("", selection: $controller.colorTarget) {
                    ForEach(SpeakerSide.allCases) { side in
                        Text(side.label).tag(side)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }

            Button {
                controller.loadWallpaperPalette()
            } label: {
                HStack(spacing: 6) {
                    if controller.isLoadingPalette {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    Text("Fetch colors from Wallpaper")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 4))
            .controlSize(.large)

            if !controller.wallpaperPalette.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Array(controller.wallpaperPalette.enumerated()), id: \.offset) { _, color in
                        Button {
                            controller.applyColor(color, to: controller.colorTarget)
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Use this color")
                    }
                }
            }

            InlineColorPicker(color: Binding(
                get: { controller.editedColor },
                set: { controller.setEditedColor($0) }
            ))
        }
        .disabled(!controller.isOn)
        .opacity(controller.isOn ? 1 : 0.5)
        
    }

    // MARK: - Footer (menu-style rows)

    private var footer: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let message = controller.updateMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }

            MenuRow(title: "Start with System", isChecked: controller.launchAtLogin) {
                controller.launchAtLogin.toggle()
            }
            MenuRow(title: "Check for Updates", trailingSystemImage: "arrow.up.right.square") {
                controller.checkForUpdates()
            }
            MenuRow(title: "Quit Prismatic") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, -8)
    }
}

/// A native-menu-style row: full-width, hover highlight, optional leading check mark.
private struct MenuRow: View {
    let title: String
    var isChecked: Bool = false
    var trailingSystemImage: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.85))
                Spacer(minLength: 0)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 11, weight: .semibold))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(isChecked ? 1 : 0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundStyle(hovering ? Color.white : Color.primary)
            .background(hovering ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

#if DEBUG
@MainActor
private func previewController(
    status: ConnectionStatus = .connected,
    on: Bool = true,
    palette: Bool = true
) -> LEDController {
    let controller = LEDController()           // runs in preview mode: no USB, no persistence
    controller.status = status
    controller.isOn = on
    if palette {
        controller.wallpaperPalette = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .pink]
    }
    return controller
}

#Preview("Connected") {
    MenuContentView(controller: previewController())
}

#Preview("Disconnected") {
    MenuContentView(controller: previewController(status: .disconnected, palette: false))
}

#Preview("Off") {
    MenuContentView(controller: previewController(on: false))
}
#endif
