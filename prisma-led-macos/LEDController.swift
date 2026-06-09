import SwiftUI
import Observation
import ServiceManagement
import AppKit

enum ConnectionStatus: Equatable {
    case connecting
    case connected
    case disconnected
}

enum SpeakerSide: String, CaseIterable, Identifiable {
    case both, left, right
    var id: String { rawValue }
    var label: String {
        switch self {
        case .both: return "Both"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

/// Persisted user settings, stored in `UserDefaults` as JSON.
private struct Settings: Codable {
    var left: RGB
    var right: RGB
    var isOn: Bool
    var linked: Bool
    var brightness: Double

    static let `default` = Settings(
        left: RGB(red: 0, green: 150, blue: 255),
        right: RGB(red: 255, green: 40, blue: 120),
        isOn: true,
        linked: false,
        brightness: 1.0
    )
}

@MainActor
@Observable
final class LEDController {
    // User-facing, persisted state.
    var leftColor: Color { didSet { onLeftChanged() } }
    var rightColor: Color { didSet { onRightChanged() } }
    var isOn: Bool { didSet { changed() } }
    var linked: Bool { didSet { onLinkedChanged() } }
    var brightness: Double { didSet { changed() } }

    // Transient UI state.
    var status: ConnectionStatus = .connecting
    var statusMessage: String?
    var wallpaperPalette: [Color] = []
    var isLoadingPalette = false
    /// Which speaker(s) the color picker and wallpaper swatches edit.
    var colorTarget: SpeakerSide = .both
    var updateMessage: String?

    /// Launch-at-login state, backed by `SMAppService`.
    var launchAtLogin: Bool { didSet { applyLaunchAtLogin() } }

    private let controller = ArenaUSBController()
    private let defaultsKey = "prisma.settings.usb"
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    private var isConfiguring = true
    private var isSyncing = false
    private var applyTask: Task<Void, Never>?

    init() {
        let settings = Self.loadSettings(key: defaultsKey)
        leftColor = Color(rgb: settings.left)
        rightColor = Color(rgb: settings.right)
        isOn = settings.isOn
        linked = settings.linked
        brightness = settings.brightness
        launchAtLogin = isPreview ? false : (SMAppService.mainApp.status == .enabled)
        isConfiguring = false
        connect()
    }

    // MARK: - Color target

    /// The color currently shown in the picker (for the selected target).
    var editedColor: Color {
        switch colorTarget {
        case .both, .left: return leftColor
        case .right: return rightColor
        }
    }

    /// Applies a color from the picker to whatever target is selected.
    func setEditedColor(_ color: Color) {
        applyColor(color, to: colorTarget)
    }

    // MARK: - Login item

    private func applyLaunchAtLogin() {
        guard !isConfiguring, !isPreview else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = "Couldn't update login item: \(error.localizedDescription)"
            // Reflect the real state back.
            isConfiguring = true
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            isConfiguring = false
        }
    }

    // MARK: - Updates

    func checkForUpdates() {
        updateMessage = "Checking for updates…"
        Task {
            switch await UpdateChecker.check() {
            case .upToDate:
                updateMessage = "You're on the latest version (v\(AppInfo.version))."
            case .updateAvailable(let tag):
                updateMessage = "Update \(tag) available — opening download…"
                NSWorkspace.shared.open(AppInfo.latestReleaseURL)
            case .failed:
                updateMessage = nil
                NSWorkspace.shared.open(AppInfo.latestReleaseURL)
            }
        }
    }

    // MARK: - Connection

    func connect() {
        if isPreview { status = .connected; statusMessage = nil; return }
        status = .connecting
        statusMessage = nil
        do {
            try controller.connect()
            status = .connected
            statusMessage = nil
            pushColors()
        } catch {
            status = .disconnected
            statusMessage = error.localizedDescription
        }
    }

    func reconnect() { connect() }

    // MARK: - Mutations

    func togglePower() { isOn.toggle() }

    /// Applies a palette/picker color to the given target.
    func applyColor(_ color: Color, to side: SpeakerSide) {
        switch side {
        case .both:
            isSyncing = true
            leftColor = color
            rightColor = color
            isSyncing = false
            changed()
        case .left:
            leftColor = color
        case .right:
            rightColor = color
        }
    }

    func loadWallpaperPalette() {
        isLoadingPalette = true
        Task {
            let colors = await WallpaperPalette.dominantColors(count: 8)
            self.wallpaperPalette = colors
            self.isLoadingPalette = false
        }
    }

    // MARK: - didSet plumbing

    private func onLeftChanged() {
        guard !isConfiguring, !isSyncing else { return }
        if linked { isSyncing = true; rightColor = leftColor; isSyncing = false }
        changed()
    }

    private func onRightChanged() {
        guard !isConfiguring, !isSyncing else { return }
        if linked { isSyncing = true; leftColor = rightColor; isSyncing = false }
        changed()
    }

    private func onLinkedChanged() {
        guard !isConfiguring else { return }
        if linked { isSyncing = true; rightColor = leftColor; isSyncing = false }
        changed()
    }

    private func changed() {
        guard !isConfiguring else { return }
        save()
        scheduleApply()
    }

    private func scheduleApply() {
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
            self.pushColors()
        }
    }

    private func pushColors() {
        guard !isPreview, status == .connected else { return }
        do {
            if isOn {
                let left = leftColor.rgb255
                let right = rightColor.rgb255
                // zone order: left base, left rear, right base, right rear
                let brightnessLevel = Int((brightness * 10).rounded())
                try controller.setZones([left, left, right, right], brightness: brightnessLevel)
            } else {
                try controller.turnOff()
            }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    // MARK: - Persistence

    private func save() {
        guard !isPreview else { return }
        let settings = Settings(
            left: leftColor.rgb255,
            right: rightColor.rgb255,
            isOn: isOn,
            linked: linked,
            brightness: brightness
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func loadSettings(key: String) -> Settings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return .default }
        return settings
    }
}
